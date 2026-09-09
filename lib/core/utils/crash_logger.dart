import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Installs global error handlers and appends every uncaught error to a
/// bounded log under the app documents directory.
///
/// This is the self-contained swallowing point for production: it captures
/// zone errors, Flutter framework errors and platform dispatcher errors so
/// crashes are diagnosable without an external reporting service. When a
/// service (Sentry/Crashlytics) is wired up later, replace [_append] with
/// its record call — everything else stays.
class CrashLogger {
  CrashLogger._();

  static File? _log;
  static const int _maxBytes = 512 * 1024;

  /// Must be called once from `main()` (inside `runZonedGuarded`).
  static void init() {
    unawaited(_open());
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _append(
        'FlutterError: ${details.exceptionAsString()}'
        '\n${details.stack ?? ''}'
        '\n--- context: ${details.context}',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _append('PlatformDispatcher: $error\n$stack');
      return true;
    };
  }

  /// Records an error that escapes the root zone (e.g. unawaited futures).
  static void recordZone(Object error, StackTrace stack) {
    _append('Zone: $error\n$stack');
  }

  /// Records a non-fatal, app-level error (server 5xx, parse failure, ...).
  static void record(String label, Object error, [StackTrace? stack]) {
    _append('$label: $error\n${stack ?? ''}');
  }

  static Future<void> _open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _log = File('${dir.path}/wizzo_crash.log');
      _append('--- app start '
          'dart ${Platform.version.split(' ').first}, '
          'os ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (_) {
      _log = null;
    }
  }

  static void _append(String message) {
    final log = _log;
    if (log == null) return;
    unawaited(() async {
      try {
        final stamp = DateTime.now().toIso8601String();
        await log.writeAsString('[$stamp] $message\n', mode: FileMode.append);
        if (await log.length() > _maxBytes) {
          final current = await log.readAsString();
          final trimmed = current.substring(current.length - (_maxBytes ~/ 2));
          await log.writeAsString(trimmed, flush: true);
        }
      } catch (_) {}
    }());
  }
}