import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for session + UI preferences.
class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _prefs;

  static const _kAccessToken = 'wizzo_access_token';
  static const _kRefreshToken = 'wizzo_refresh_token';
  static const _kUser = 'wizzo_user';
  static const _kOnboardingSeen = 'wizzo_onboarding_seen';
  static const _kThemeMode = 'wizzo_theme_mode';
  static const _kLanguage = 'wizzo_language';
  static const _kLastCity = 'wizzo_last_city';
  static const _kNotifyOrders = 'wizzo_notify_orders';
  static const _kNotifyChat = 'wizzo_notify_chat';
  static const _kNotifyPromo = 'wizzo_notify_promo';
  static const _kNotifySystem = 'wizzo_notify_system';
  static const _kCurrency = 'wizzo_currency';

  static Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ---- Session ---------------------------------------------------------
  static Future<String?> accessToken() async =>
      (await _instance).getString(_kAccessToken);
  static Future<String?> refreshToken() async =>
      (await _instance).getString(_kRefreshToken);
  static Future<String?> userJson() async =>
      (await _instance).getString(_kUser);

  static Future<void> saveSession(
    String access,
    String refresh,
    Map<String, dynamic> user,
  ) async {
    final p = await _instance;
    await p.setString(_kAccessToken, access);
    await p.setString(_kRefreshToken, refresh);
    if (user.isNotEmpty) {
      await p.setString(_kUser, mapToJson(user));
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final p = await _instance;
    await p.setString(_kUser, mapToJson(user));
  }

  static Future<void> clearSession() async {
    final p = await _instance;
    await p.remove(_kAccessToken);
    await p.remove(_kRefreshToken);
    await p.remove(_kUser);
  }

  // ---- UI preferences ---------------------------------------------------
  static Future<bool> onboardingSeen() async =>
      (await _instance).getBool(_kOnboardingSeen) ?? false;

  static Future<void> setOnboardingSeen(bool value) async {
    (await _instance).setBool(_kOnboardingSeen, value);
  }

  static Future<String> themeMode() async =>
      (await _instance).getString(_kThemeMode) ?? 'system';

  static Future<void> setThemeMode(String value) async {
    (await _instance).setString(_kThemeMode, value);
  }

  static Future<String> language() async =>
      (await _instance).getString(_kLanguage) ?? 'en';

  static Future<void> setLanguage(String value) async {
    (await _instance).setString(_kLanguage, value);
  }

  static Future<String> lastCity() async =>
      (await _instance).getString(_kLastCity) ?? '';

  static Future<void> setLastCity(String value) async {
    (await _instance).setString(_kLastCity, value);
  }

  // ---- Notification preferences ------------------------------------------
  static Future<bool> notifyOrders() async =>
      (await _instance).getBool(_kNotifyOrders) ?? true;

  static Future<void> setNotifyOrders(bool value) async {
    (await _instance).setBool(_kNotifyOrders, value);
  }

  static Future<bool> notifyChat() async =>
      (await _instance).getBool(_kNotifyChat) ?? true;

  static Future<void> setNotifyChat(bool value) async {
    (await _instance).setBool(_kNotifyChat, value);
  }

  static Future<bool> notifyPromo() async =>
      (await _instance).getBool(_kNotifyPromo) ?? true;

  static Future<void> setNotifyPromo(bool value) async {
    (await _instance).setBool(_kNotifyPromo, value);
  }

  static Future<bool> notifySystem() async =>
      (await _instance).getBool(_kNotifySystem) ?? true;

  static Future<void> setNotifySystem(bool value) async {
    (await _instance).setBool(_kNotifySystem, value);
  }

  // ---- Display currency --------------------------------------------------
  static Future<Map<String, dynamic>?> currency() async {
    final raw = (await _instance).getString(_kCurrency);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCurrency(
    String code,
    Map<String, double>? rates,
    DateTime? updatedAt,
  ) async {
    final prefs = await _instance;
    await prefs.setString(
      _kCurrency,
      jsonEncode({
        'code': code,
        'rates': ?rates,
        'ratesUpdatedAt': ?updatedAt?.millisecondsSinceEpoch,
      }),
    );
  }

  static String mapToJson(Map<String, dynamic> map) => jsonEncode(map);
}
