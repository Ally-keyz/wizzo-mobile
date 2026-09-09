import 'dart:convert';

import 'package:easy_localization/src/localization.dart' show Localization;
import 'package:easy_localization/src/translations.dart' show Translations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Deterministic localization harness for widget tests.
///
/// Loads the real `assets/l10n/en.json` through a plain
/// [LocalizationsDelegate] and injects the same global Material delegates the
/// app uses — without mounting the `EasyLocalization` widget, whose async
/// controller listener is notoriously flaky under the test framework
/// (deactivated-context lookups at teardown).
class _TestLocalizationDelegate extends LocalizationsDelegate<Localization> {
  const _TestLocalizationDelegate(this.locale);

  final String locale;

  @override
  Future<Localization> load(Locale l) async {
    final data = await rootBundle.loadString('assets/l10n/$locale.json');
    Localization.load(
      l,
      translations: Translations(
        Map<String, dynamic>.from(jsonDecode(data) as Map),
      ),
    );
    return Localization.instance;
  }

  @override
  bool isSupported(Locale locale) => locale.languageCode == this.locale;

  @override
  bool shouldReload(_TestLocalizationDelegate old) => false;
}

/// Wraps [child] in a `MaterialApp` configured like the production app but
/// backed by real localized strings and no network-facing plugins.
Widget localizedApp(Widget child, {ThemeData? theme}) {
  return Builder(
    builder: (context) => MaterialApp(
      theme: theme,
      localizationsDelegates: [
        const _TestLocalizationDelegate('en'),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: child,
    ),
  );
}
