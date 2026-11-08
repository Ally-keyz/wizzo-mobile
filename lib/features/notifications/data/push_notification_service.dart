import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_providers.dart';
import '../../../core/routing/navigator_keys.dart';

/// Android channel shared with the backend's FCM payloads. The server sends
/// `channelId: wizzo_new_products`, so the channel must be created before the
/// first notification arrives.
const _androidChannelId = 'wizzo_new_products';
const _androidChannel = AndroidNotificationChannel(
  _androidChannelId,
  'New products and updates',
  description: 'New arrivals, order updates and messages from Wizzo Market.',
  importance: Importance.high,
);

/// Runs in a background isolate when a data-only message arrives while the app
/// is terminated. Notification payloads are displayed by the OS itself; this
/// handler only needs Firebase to be initialized so the plugin can dispatch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase credentials are not configured in this build.
  }
}

/// Owns Firebase Messaging + local notification presentation for the app.
///
/// Firebase is optional: builds without `google-services.json` /
/// `GoogleService-Info.plist` still run normally, they just cannot receive
/// device notifications. Every Firebase call is therefore guarded.
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _firebaseChecked = false;
  static bool _firebaseReady = false;

  bool _initialized = false;
  bool _permissionRequested = false;
  String? _currentUserId;
  String? _token;
  StreamSubscription<String>? _tokenSubscription;

  /// Initializes Firebase once per process, before `runApp`, so a notification
  /// tap that launched the app is available through `getInitialMessage`.
  static Future<void> bootstrap() async {
    if (_firebaseChecked) return;
    _firebaseChecked = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error) {
      debugPrint('Device notifications unavailable: $error');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await PushNotificationService.bootstrap();
    if (!_firebaseReady) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_foreground'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _local.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          _handlePayload(response.payload);
        },
      );

      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_androidChannel);
      }

      // Foreground notifications are shown by our local-notifications layer,
      // so avoid the duplicate banner iOS would otherwise present itself.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _navigateForData(message.data),
      );

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _navigateForData(initial.data);
      }
    } catch (error) {
      debugPrint('Could not initialize device notifications: $error');
    }
  }

  /// Asks for the OS notification permission and registers this install's FCM
  /// token with the backend for [userId]. Safe to call on every sign-in; the
  /// permission prompt only appears the first time.
  Future<void> registerForUser(String userId) async {
    await initialize();
    if (!_firebaseReady) return;
    if (_currentUserId == userId && _token != null) return;
    _currentUserId = userId;

    try {
      if (!_permissionRequested) {
        _permissionRequested = true;
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (Platform.isAndroid) {
          await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        await _sendTokenToServer(token);
      }

      _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          _token = token;
          if (_currentUserId != null) {
            _sendTokenToServer(token);
          }
        },
      );
    } catch (error) {
      debugPrint('Could not register device notifications: $error');
    }
  }

  /// Stops notifications for the signed-out account. Called before the auth
  /// token is cleared so the backend can remove this device from the user.
  Future<void> unregisterForUser() async {
    final token =
        _token ??
        (PushNotificationService._firebaseReady
            ? await FirebaseMessaging.instance.getToken()
            : null);
    if (token != null && token.isNotEmpty) {
      try {
        await _ref
            .read(apiClientProvider)
            .delete('/auth/fcm-token', body: {'token': token});
      } catch (_) {
        // Best effort: the account may already be gone or offline.
      }
    }

    _currentUserId = null;
    _token = null;
    try {
      if (PushNotificationService._firebaseReady) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {
      // Nothing else to clean up locally.
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post('/auth/fcm-token', body: {'token': token});
    } catch (error) {
      debugPrint('Could not save the notification token: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Wizzo Market';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    try {
      await _local.show(
        _notificationId(message),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            'New products and updates',
            channelDescription:
                'New arrivals, order updates and messages from Wizzo Market.',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_launcher_foreground',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error) {
      debugPrint('Could not show device notification: $error');
    }
  }

  int _notificationId(RemoteMessage message) {
    final id = message.messageId;
    if (id != null && id.isNotEmpty) return id.hashCode & 0x7fffffff;
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _navigateForData(decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {
      // Ignore a malformed payload and leave the user where they are.
    }
  }

  /// Opens the most specific screen the notification knows about, matching the
  /// in-app notification list's routing rules.
  void _navigateForData(Map<String, dynamic> data) {
    String? value(String key) {
      final raw = data[key]?.toString().trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    final conversationId = value('conversationId');
    final orderId = value('orderId');
    final productId = value('productId');
    final store = value('storeSlug') ?? value('storeId');

    final target = conversationId != null
        ? '/conversation/${Uri.encodeComponent(conversationId)}'
        : orderId != null
        ? '/order/${Uri.encodeComponent(orderId)}'
        : productId != null
        ? '/product/${Uri.encodeComponent(productId)}'
        : store != null
        ? '/shop/${Uri.encodeComponent(store)}'
        : '/notifications';

    _pushRoute(target);
  }

  void _pushRoute(String target) {
    void open() {
      final context = rootNavigatorKey.currentContext;
      if (context != null) GoRouter.of(context).push(target);
    }

    // The router/navigator may not exist yet on a cold start, so try now and
    // again after the first frame.
    open();
    WidgetsBinding.instance.addPostFrameCallback((_) => open());
    Future<void>.delayed(const Duration(milliseconds: 600), open);
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});
