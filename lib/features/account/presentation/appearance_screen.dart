import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../settings/theme_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('account.appearance'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr('appearance.chooseLook'),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          _modeCard(ref, context, theme, context.tr('appearance.systemDefault'), context.tr('appearance.systemDefaultSubtitle'), ThemeMode.system, current, Icons.settings_suggest_outlined),
          _modeCard(ref, context, theme, context.tr('appearance.light'), context.tr('appearance.lightSubtitle'), ThemeMode.light, current, Icons.light_mode_outlined),
          _modeCard(ref, context, theme, context.tr('appearance.dark'), context.tr('appearance.darkSubtitle'), ThemeMode.dark, current, Icons.dark_mode_outlined),
        ],
      ),
    );
  }

  Widget _modeCard(WidgetRef ref, BuildContext context, ThemeData theme, String label, String subtitle, ThemeMode mode, ThemeMode current, IconData icon) {
    final selected = mode == current;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Palette.gold : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Palette.gold : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 22, color: selected ? Palette.gold : theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}