import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_sheet.dart';

const _whatsAppCommunityUrl =
    'https://chat.whatsapp.com/HEeBCmTxFVKAXLNsU8hbZT?s=cl&p=i&mlu=4&ilr=4';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  static List<(String, IconData, String)> _topics(BuildContext context) => [
    (context.tr('help.ordersDelivery'), Icons.local_shipping_outlined, context.tr('help.ordersDeliverySubtitle')),
    (context.tr('help.returnsRefunds'), Icons.replay_outlined, context.tr('help.returnsRefundsSubtitle')),
    (context.tr('help.paymentsWallet'), Icons.payments_outlined, context.tr('help.paymentsWalletSubtitle')),
    (context.tr('help.accountSecurity'), Icons.security_outlined, context.tr('help.accountSecuritySubtitle')),
    (context.tr('help.sellingOnWizzo'), Icons.storefront_outlined, context.tr('help.sellingOnWizzoSubtitle')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('help.title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.infoContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent, size: 30, color: context.appColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('help.needHelp'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: context.appColors.onInfoContainer)),
                      Text(context.tr('help.reachUs', namedArgs: {'email': AppConfig.supportEmail}), style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.onInfoContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(context.tr('help.browseTopics'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final topic in _topics(context))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: Icon(topic.$2, color: context.appColors.info),
                title: Text(topic.$1, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(topic.$3, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => ComingSoonSheet.show(
                  context,
                  title: topic.$1,
                  description: context.tr('help.topicComingSoon', namedArgs: {'email': AppConfig.supportEmail}),
                  icon: topic.$2,
                  ctaLabel: context.tr('common.gotIt'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final launched = await launchUrl(
                Uri.parse(_whatsAppCommunityUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(context.tr('common.linkOpenError')),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat, color: Color(0xFF25D366)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('help.joinWhatsapp'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}