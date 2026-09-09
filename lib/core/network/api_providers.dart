import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_prefs.dart';
import 'api_client.dart';

/// Shared [ApiClient] with session hooks wired by the auth controller.
final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  api.onAccessToken = AppPrefs.accessToken;
  return api;
});