import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_widgets.dart';
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
                  onTap: !n.read
                      ? () => ref
                            .read(notificationsProvider.notifier)
                            .markRead(n.id)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
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

    return GestureDetector(
      onTap: onTap,
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
                      relativeDate(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.read)
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
