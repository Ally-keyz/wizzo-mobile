import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Fallback [MaterialLocalizations] for app locales the stock
/// `GlobalMaterialLocalizations` does not ship (e.g. Kinyarwanda `rw`).
///
/// The framework's `_loadAll` only loads the *first* delegate of each type
/// whose `isSupported` returns true, so this delegate is only consulted for
/// locales the built-in delegate rejects. For those locales we proxy to the
/// English strings so stock Material widgets render instead of throwing
/// "No MaterialLocalizations found".
class RWMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const RWMaterialLocalizationsDelegate(this.appLocales);

  final List<Locale> appLocales;

  @override
  bool isSupported(Locale locale) =>
      appLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(
        GlobalMaterialLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );

  @override
  bool shouldReload(RWMaterialLocalizationsDelegate old) =>
      old.appLocales.length != appLocales.length;
}

/// Fallback [CupertinoLocalizations] for app locales the stock
/// `GlobalCupertinoLocalizations` does not ship (e.g. Kinyarwanda `rw`).
///
/// See [RWMaterialLocalizationsDelegate] for the loading strategy.
class RWCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const RWCupertinoLocalizationsDelegate(this.appLocales);

  final List<Locale> appLocales;

  @override
  bool isSupported(Locale locale) =>
      appLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(
        GlobalCupertinoLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );

  @override
  bool shouldReload(RWCupertinoLocalizationsDelegate old) =>
      old.appLocales.length != appLocales.length;
}