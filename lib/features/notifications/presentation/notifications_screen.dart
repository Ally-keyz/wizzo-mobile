import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notification_repository.dart';
import '../models/notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('notif.screenTitle'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          async.value?.any((n) => !n.read) == true
              ? TextButton(
                  onPressed: () =>
                      ref.read(notificationsProvider.notifier).markAllRead(),
                  child: Text(context.tr('notif.markAllRead')),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.notifications_off_outlined,
          title: context.tr('notif.loadError'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return WEmptyState(
              icon: Icons.notifications_none,
              title: context.tr('notif.emptyTitle'),
              subtitle: context.tr('notif.emptyBody'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _open(context, ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Opens whatever the notification is about, then marks it read.
  ///
  /// Navigation happens first and the read receipt is fired off in the
  /// background — tapping a notice should move immediately, not wait on the
  /// network. Notices with no target (announcements, system pings) still get
  /// their unread dot cleared.
  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    if (!n.read) {
      unawaited(
        ref.read(notificationsProvider.notifier).markRead(n.id).catchError((_) {}),
      );
    }

    final target = n.target;
    if (target == null) return;

    // Sellers get their own order screen; the buyer one 403s on someone
    // else's order.
    final isSeller = ref.read(authControllerProvider).user?.isSeller ?? false;

    switch (target.kind) {
      case NotificationTargetKind.conversation:
        context.push('/conversation/${target.id}');
      case NotificationTargetKind.order:
        context.push(isSeller ? '/seller/order/${target.id}' : '/order/${target.id}');
      case NotificationTargetKind.store:
        context.push('/shop/${target.id}');
      case NotificationTargetKind.product:
        context.push('/product/${target.id}');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (notification.type) {
      NotificationType.order => Icons.receipt_long_outlined,
      NotificationType.chat => Icons.chat_bubble_outline,
      NotificationType.promo => Icons.local_offer_outlined,
      NotificationType.system => Icons.notifications_outlined,
    };
    final hasTarget = notification.target != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.read
              ? theme.colorScheme.surface
              : context.appColors.infoContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appColors.infoContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: context.appColors.info),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title.isNotEmpty
                        ? notification.title
                        : context.tr('notif.updateFallback'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: notification.read
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  if (notification.message != null &&
                      notification.message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      relativeDate(context, notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasTarget)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 10),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              )
            else if (!notification.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Palette.gold,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
