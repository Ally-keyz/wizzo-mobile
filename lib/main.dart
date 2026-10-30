import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/currency/currency_controller.dart';
import 'core/network/api_exception.dart';
import 'core/storage/app_prefs.dart';
import 'core/utils/crash_logger.dart';

/// Riverpod 3 retries failed providers automatically. Client errors (400, 401,
/// 403, 404...) can never succeed on a retry, and retrying them keeps screens
/// on their loading skeleton for tens of seconds — which looks like an
/// infinite spinner. Only transient failures (timeouts, network drops, 5xx)
/// are retried.
Duration? _retryPolicy(int retryCount, Object error) {
  if (error is ApiException && error.status >= 400 && error.status < 500) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

Future<void> main() async {
  // Catches uncaught errors (zone, Flutter framework, platform dispatcher)
  // and writes them to <documents>/wizzo_crash.log for production diagnosis.
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      CrashLogger.init();
      final langCode = await AppPrefs.language();
      await currencyController.init();
      runApp(
        EasyLocalization(
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
            Locale('rw'),
            Locale('de'),
            Locale('sw'),
          ],
          path: 'assets/l10n',
          fallbackLocale: const Locale('en'),
          startLocale: Locale(langCode),
          child: ProviderScope(retry: _retryPolicy, child: const WizzoApp()),
        ),
      );
    },
    CrashLogger.recordZone,
  );
}
