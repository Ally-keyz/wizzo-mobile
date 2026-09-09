import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/storage/app_prefs.dart';
import '../../seller/data/seller_repository.dart';
import '../../seller/providers/seller_providers.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

class AuthState {
  const AuthState({this.user, this.initializing = true});

  final User? user;
  final bool initializing;

  bool get isSignedIn => !initializing && user != null && user!.id.isNotEmpty;
  bool get isGuest => !initializing && user == null;
}

class AuthController extends Notifier<AuthState> {
  bool _upgradingRole = false;

  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  Future<void> _init() async {
    final api = ref.read(apiClientProvider);
    final repo = ref.read(authRepositoryProvider);

    api.onAccessToken = AppPrefs.accessToken;
    api.onRefresh = repo.refresh;
    api.onSessionExpired = () {
      _signOutSilently();
    };

    final access = await AppPrefs.accessToken();
    final userJson = await AppPrefs.userJson();
    if (access != null && access.isNotEmpty && userJson != null) {
      final user = User.fromApi(_decodeUser(userJson));
      state = AuthState(user: user, initializing: false);
    } else {
      state = AuthState(user: null, initializing: false);
    }
  }

  Map<String, dynamic> _decodeUser(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {};
  }

  Future<void> login({required String email, required String password}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .login(email.trim(), password);
    await _accept(result);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .register(fullName: fullName, email: email, password: password);
    await _accept(result);
  }

  Future<void> registerSeller({
    required String fullName,
    required String email,
    required String password,
    required String storeName,
    String? aboutStore,
    String? country,
    String? district,
    String? city,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .registerSeller(
          fullName: fullName,
          email: email,
          password: password,
          storeName: storeName,
          aboutStore: aboutStore,
          country: country,
          district: district,
          city: city,
        );
    await _accept(result);
  }

  /// Creates a store for an existing (buyer) account, then force-refreshes the
  /// token so the JWT carries the new `seller` role and reloads the user.
  Future<User> registerStore({
    required String storeName,
    String? aboutStore,
    String? logoUrl,
    String? country,
    String? district,
    String? city,
    double? longitude,
    double? latitude,
  }) async {
    await ref.read(sellerRepositoryProvider).registerStore(
          storeName: storeName,
          aboutStore: aboutStore,
          logoUrl: logoUrl,
          country: country,
          district: district,
          city: city,
          longitude: longitude,
          latitude: latitude,
        );

    return _refreshRoleAndUser();
  }

  /// Refreshes the JWT and reloads the user so the session's stored role
  /// matches reality. Used after store creation and, via [syncRoleWithStore],
  /// for accounts that already had a store when they signed in (their login
  /// token still carries the old `buyer` role, which makes role-protected
  /// seller endpoints return 403).
  Future<User> _refreshRoleAndUser() async {
    final repo = ref.read(authRepositoryProvider);
    final refreshed = await repo.refresh();
    if (refreshed == null) {
      throw const ApiException(
        status: 0,
        code: 'auth',
        message: 'Your session could not be upgraded. Sign in again.',
      );
    }

    final currentRefresh = await AppPrefs.refreshToken();
    final data = await ref.read(apiClientProvider).get('/users/me');
    final rawUser =
        data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
            ? data['user']
            : data;
    final user = User.fromApi(rawUser);
    await repo.persistSession(
      AuthResult(accessToken: refreshed, refreshToken: currentRefresh, user: user),
    );
    state = AuthState(user: user, initializing: false);
    return user;
  }

  /// Best-effort role upgrade: never throws. Signature is idempotent, so the
  /// seller gate can call it safely on every rebuild until the role flips.
  Future<void> syncRoleWithStore() async {
    if (_upgradingRole) return;
    _upgradingRole = true;
    try {
      await _refreshRoleAndUser();
      ref.invalidate(sellerStatsProvider);
      ref.invalidate(sellerOrdersProvider);
      ref.invalidate(myProductsProvider);
    } catch (_) {
      // Offline or transient failure: buyer endpoints still work and the
      // seller screens surface their own per-request errors with retry.
    } finally {
      _upgradingRole = false;
    }
  }

  Future<void> sendEmailOtp(String email) {
    return ref.read(authRepositoryProvider).sendEmailOtp(email);
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    await ref.read(authRepositoryProvider).verifyEmailOtp(email, code);
    await markEmailVerified();
  }

  Future<void> markEmailVerified() async {
    final current = state.user;
    if (current == null) return;
    final updated = current.copyWith(emailVerified: true);
    await AppPrefs.saveUser(updated.toJson());
    state = AuthState(user: updated, initializing: false);
  }

  Future<void> google() async {
    final result = await ref.read(authRepositoryProvider).google();
    await _accept(result);
  }

  Future<void> _accept(AuthResult result) async {
    if (result.accessToken == null) {
      throw const ApiException(
        status: 0,
        code: 'auth',
        message: 'Sign-in failed. Please try again.',
      );
    }
    final repo = ref.read(authRepositoryProvider);
    await repo.persistSession(result);
    state = AuthState(user: result.user, initializing: false);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await _signOutSilently();
  }

  Future<void> _signOutSilently() async {
    await AppPrefs.clearSession();
    state = AuthState(user: null, initializing: false);
  }

  Future<void> updateUser(User user) async {
    await AppPrefs.saveUser(user.toJson());
    state = AuthState(user: user, initializing: false);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
