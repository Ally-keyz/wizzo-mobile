import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';

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

  Future<AuthResult> google() async {
    // Only pass non-empty values. On Android an empty `serverClientId` string
    // would make the native plugin call requestIdToken('') and fail instead of
    // falling back to requestEmail-only sign-in.
    final serverClientId =
        AppConfig.googleServerClientId.trim().isEmpty
            ? null
            : AppConfig.googleServerClientId.trim();
    final google = GoogleSignIn(
      clientId:
          AppConfig.googleAndroidClientId.trim().isEmpty
              ? null
              : AppConfig.googleAndroidClientId.trim(),
      serverClientId: serverClientId,
      scopes: ['email', 'profile'],
    );
    try {
      final account = await google.signIn();
      if (account == null) {
        throw const ApiException(
          status: 0,
          code: 'cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }
      final idToken = await account.authentication.then((a) => a.idToken);
      if (idToken == null) {
        // On Android an ID token is only issued when an OAuth audience is
        // configured: the app needs `serverClientId` (the web client id) and
        // the signing key's SHA-1 registered in the Google Cloud console.
        CrashLogger.record(
          'auth/google',
          'idToken is null: app built without Google OAuth config',
        );
        throw const ApiException(
          status: 0,
          code: 'google-config',
          message: 'Google sign-in didn\'t return an auth token. '
              'Make sure the app is signed with the registered key, '
              'or use email sign-in in the meantime.',
        );
      }
      final data = await _api.post('/auth/google', body: {'idToken': idToken});
      return _toResult(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      // Surface the real Google error (e.g. "10: DEVELOPER_ERROR" for an
      // unregistered signing fingerprint) and record it for diagnosis.
      CrashLogger.record('auth/google', e);
      final detail = e.toString().trim();
      final hint = detail.contains('10:')
          ? ' (the app signing key is not registered with Google Cloud — '
                'add the SHA-1 fingerprint of this build\'s signing key to '
                'the Android OAuth client.)'
          : '';
      throw ApiException(
        status: 0,
        code: 'google',
        message:
            'Google sign-in failed: $detail$hint '
            'Use email sign-in in the meantime.',
      );
    }
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
