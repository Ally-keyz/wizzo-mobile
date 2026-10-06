import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/crash_logger.dart';
import '../models/user.dart';

/// All auth endpoints against the real backend.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    return _toResult(data);
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return _toResult(data);
  }

  Future<AuthResult> registerSeller({
    required String fullName,
    required String email,
    required String password,
    required String storeName,
    String? aboutStore,
    String? country,
    String? district,
    String? city,
  }) async {
    final data = await _api.post(
      '/auth/register-seller',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'storeName': storeName.trim(),
        'aboutStore': aboutStore?.trim(),
        'country': country?.trim(),
        'district': district?.trim(),
        'city': city?.trim(),
      },
    );
    return _toResult(data);
  }

  Future<void> sendEmailOtp(String email) async {
    await _api.post('/auth/email/send-otp', body: {'email': email.trim()});
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    await _api.post(
      '/auth/email/verify',
      body: {'email': email.trim(), 'code': code.trim()},
    );
  }

  /// Refreshes tokens; returns the new access token or null on failure.
  Future<String?> refresh() async {
    final refreshToken = await AppPrefs.refreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final data = await _api.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      if (data is Map) {
        final access = data['accessToken']?.toString();
        final refresh = data['refreshToken']?.toString();
        if (access != null && access.isNotEmpty) {
          final currentUser = await AppPrefs.userJson();
          final user = currentUser == null
              ? <String, dynamic>{}
              : jsonDecode(currentUser);
          await AppPrefs.saveSession(
            access,
            (refresh != null && refresh.isNotEmpty) ? refresh : refreshToken,
            user is Map<String, dynamic> ? user : <String, dynamic>{},
          );
          return access;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', body: {'email': email.trim()});
  }

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    await _api.post(
      '/auth/change-email',
      body: {'currentPassword': currentPassword, 'newEmail': newEmail.trim()},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Never block sign-out on a network error.
    }
  }

  Future<void> persistSession(AuthResult result) async {
    await AppPrefs.saveSession(
      result.accessToken!,
      result.refreshToken ?? '',
      result.user?.toJson() ?? <String, dynamic>{},
    );
  }

  AuthResult _toResult(dynamic data) {
    var payload = data;
    if (payload is Map && payload['data'] is Map) {
      // Some endpoints nest under {success, data: {accessToken, user}}.
      payload = payload['data'];
    }
    if (payload is! Map<String, dynamic>) {
      throw const ApiException(
        status: 0,
        code: 'auth',
        message: 'The server returned an invalid response.',
      );
    }

    // Real backend shape: { user: {...}, tokens: { accessToken, refreshToken } }.
    final tokens = payload['tokens'];
    final tokenMap = tokens is Map<String, dynamic>
        ? tokens
        : const <String, dynamic>{};
    final token =
        tokenMap['accessToken']?.toString() ??
        payload['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        status: 0,
        code: 'auth',
        message: 'The server returned an invalid response.',
      );
    }

    final userRaw = payload['user'];
    final user = userRaw is Map<String, dynamic>
        ? User.fromApi(userRaw)
        : const User(id: '');

    return AuthResult(
      accessToken: token,
      refreshToken:
          tokenMap['refreshToken']?.toString() ??
          payload['refreshToken']?.toString(),
      user: user.id.isEmpty ? null : user,
    );
  }
}

class AuthResult {
  const AuthResult({this.accessToken, this.refreshToken, this.user});

  final String? accessToken;
  final String? refreshToken;
  final User? user;
}
