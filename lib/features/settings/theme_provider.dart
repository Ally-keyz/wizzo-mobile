import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_prefs.dart';

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _hydrate();
    return ThemeMode.system;
  }

  Future<void> _hydrate() async {
    final saved = await AppPrefs.themeMode();
    state = _fromName(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await AppPrefs.setThemeMode(mode.name);
  }

  ThemeMode _fromName(String name) {
    if (name == 'light') return ThemeMode.light;
    if (name == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Whether the onboarding flow has been completed.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    state = await AppPrefs.onboardingSeen();
  }

  Future<void> markSeen() async {
    state = true;
    await AppPrefs.setOnboardingSeen(true);
  }
}

final onboardingSeenProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// Active app language code ('en', 'fr', 'rw').
final languageCodeProvider = FutureProvider<String>((ref) {
  return AppPrefs.language();
});

/// Last selected city for nearby-sellers filtering.
final lastCityProvider =
    NotifierProvider<LastCityController, String>(LastCityController.new);

class LastCityController extends Notifier<String> {
  @override
  String build() {
    _hydrate();
    return '';
  }

  Future<void> _hydrate() async {
    state = await AppPrefs.lastCity();
  }

  Future<void> setCity(String city) async {
    state = city;
    await AppPrefs.setLastCity(city);
  }
}