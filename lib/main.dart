import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/currency/currency_controller.dart';
import 'core/storage/app_prefs.dart';
import 'core/utils/crash_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catches uncaught errors (zone, Flutter framework, platform dispatcher)
  // and writes them to <documents>/wizzo_crash.log for production diagnosis.
  await runZonedGuarded(
    () async {
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
          child: const ProviderScope(child: WizzoApp()),
        ),
      );
    },
    CrashLogger.recordZone,
  );
}
