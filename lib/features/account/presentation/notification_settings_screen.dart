import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/models/notification.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(notificationPrefsProvider);

    final options = <({NotificationType type, String label, String subtitle, IconData icon})>[
      (
        type: NotificationType.order,
        label: context.tr('notif.orderUpdates'),
        subtitle: context.tr('notif.orderUpdatesSubtitle'),
        icon: Icons.receipt_long_outlined,
      ),
      (
        type: NotificationType.chat,
        label: context.tr('notif.messages'),
        subtitle: context.tr('notif.messagesSubtitle'),
        icon: Icons.chat_bubble_outline,
      ),
      (
        type: NotificationType.promo,
        label: context.tr('notif.promotions'),
        subtitle: context.tr('notif.promotionsSubtitle'),
        icon: Icons.local_offer_outlined,
      ),
      (
        type: NotificationType.system,
        label: context.tr('notif.systemUpdates'),
        subtitle: context.tr('notif.systemUpdatesSubtitle'),
        icon: Icons.shield_outlined,
      ),
    ];

    bool isOn(NotificationType type) => switch (type) {
          NotificationType.order => prefs.orders,
          NotificationType.chat => prefs.chat,
          NotificationType.promo => prefs.promo,
          NotificationType.system => prefs.system,
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('account.notificationSettings'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.infoContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: context.appColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('notif.intro'),
                    style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.onInfoContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 16, endIndent: 16, color: theme.colorScheme.outlineVariant),
                  SwitchListTile(
                    value: isOn(options[i].type),
                    onChanged: (v) =>
                        ref.read(notificationPrefsProvider.notifier).set(options[i].type, v),
                    activeTrackColor: Palette.gold,
                    secondary: Icon(options[i].icon, color: context.appColors.info),
                    title: Text(
                      options[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      options[i].subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('notif.footer'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}