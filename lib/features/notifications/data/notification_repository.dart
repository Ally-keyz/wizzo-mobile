import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../core/storage/app_prefs.dart';

import '../../../core/network/api_client.dart';
import '../models/notification.dart';

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list() async {
    final data = await _api.get('/notifications');
    final items = data is List
        ? data
        : (data is Map ? (data['notifications'] ?? data['items'] ?? const []) : const []);
    if (items is! List) return const [];
    return items.map(AppNotification.fromApi).toList();
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    if (data is num) return data.toInt();
    if (data is Map) {
      final v = data['count'] ?? data['unread'];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() =>
      ref.watch(notificationRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).list(),
    );
  }

  /// Swaps in the latest list without a loading flicker (used by the live
  /// background poller so badges and banners update smoothly).
  Future<void> seed(List<AppNotification> latest) async {
    state = AsyncData(latest);
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final n in current) n.id == id ? _copyRead(n) : n,
      ]);
    }
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.map(_copyRead).toList());
    }
  }

  AppNotification _copyRead(AppNotification n) => AppNotification(
        id: n.id,
        title: n.title,
        message: n.message,
        type: n.type,
        read: true,
        createdAt: n.createdAt,
      );
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

/// Unread notification count.
final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  final value = await ref.watch(notificationsProvider.future);
  return value.where((n) => !n.read).length;
});

/// Which notification categories the user wants to receive. Persisted on-device
/// and used to gate the in-app notification banner and badges.
class NotificationPrefs {
  const NotificationPrefs({
    this.orders = true,
    this.chat = true,
    this.promo = true,
    this.system = true,
  });

  final bool orders;
  final bool chat;
  final bool promo;
  final bool system;

  bool enabledFor(NotificationType type) => switch (type) {
        NotificationType.order => orders,
        NotificationType.chat => chat,
        NotificationType.promo => promo,
        NotificationType.system => system,
      };

  NotificationPrefs copyWith({
    bool? orders,
    bool? chat,
    bool? promo,
    bool? system,
  }) {
    return NotificationPrefs(
      orders: orders ?? this.orders,
      chat: chat ?? this.chat,
      promo: promo ?? this.promo,
      system: system ?? this.system,
    );
  }
}

class NotificationPrefsController extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    _load();
    return const NotificationPrefs();
  }

  Future<void> _load() async {
    state = NotificationPrefs(
      orders: await AppPrefs.notifyOrders(),
      chat: await AppPrefs.notifyChat(),
      promo: await AppPrefs.notifyPromo(),
      system: await AppPrefs.notifySystem(),
    );
  }

  Future<void> set(NotificationType type, bool value) async {
    final current = state;
    final next = switch (type) {
      NotificationType.order => current.copyWith(orders: value),
      NotificationType.chat => current.copyWith(chat: value),
      NotificationType.promo => current.copyWith(promo: value),
      NotificationType.system => current.copyWith(system: value),
    };
    state = next;
    switch (type) {
      case NotificationType.order:
        await AppPrefs.setNotifyOrders(value);
      case NotificationType.chat:
        await AppPrefs.setNotifyChat(value);
      case NotificationType.promo:
        await AppPrefs.setNotifyPromo(value);
      case NotificationType.system:
        await AppPrefs.setNotifySystem(value);
    }
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsController, NotificationPrefs>(
  NotificationPrefsController.new,
);