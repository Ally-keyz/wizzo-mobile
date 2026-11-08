import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'push_notification_service.dart';

/// Keeps the device notification registration in sync with the signed-in
/// session. Watching this provider at the app root is what initializes Firebase
/// Messaging and registers the FCM token after login.
final pushNotificationLifecycleProvider = Provider<void>((ref) {
  final auth = ref.watch(authControllerProvider);
  final service = ref.watch(pushNotificationServiceProvider);

  // Initialize even for guests so notification taps received while signed out
  // still route correctly and the Android channel exists before the first push.
  service.initialize();

  final userId = auth.user?.id;
  if (auth.isSignedIn && userId != null && userId.isNotEmpty) {
    service.registerForUser(userId);
  }
});
