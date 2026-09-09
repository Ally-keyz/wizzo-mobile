import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

/// Shared scrollable legal document: title + intro + numbered sections.
class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({
    required this.title,
    required this.icon,
    required this.updated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String updated;
  final String intro;
  final List<({String heading, List<String> body})> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.infoContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: context.appColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('legal.lastUpdated', namedArgs: {'date': updated}),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.appColors.onInfoContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(intro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 20),
          for (final (i, section) in sections.indexed) ...[
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Palette.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.heading,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in section.body)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 8),
          Text(
            AppConfig.supportEmail.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static List<({String heading, List<String> body})> _sections(BuildContext context) => [
    (
      heading: context.tr('legal.termsSection1'),
      body: [
        context.tr('legal.termsSection1Body1'),
        context.tr('legal.termsSection1Body2'),
      ],
    ),
    (
      heading: context.tr('legal.termsSection2'),
      body: [
        context.tr('legal.termsSection2Body1'),
        context.tr('legal.termsSection2Body2'),
        context.tr('legal.termsSection2Body3'),
      ],
    ),
    (
      heading: context.tr('legal.termsSection3'),
      body: [
        context.tr('legal.termsSection3Body1'),
        context.tr('legal.termsSection3Body2'),
      ],
    ),
    (
      heading: context.tr('legal.termsSection4'),
      body: [
        context.tr('legal.termsSection4Body1', namedArgs: {'email': AppConfig.supportEmail}),
        context.tr('legal.termsSection4Body2'),
      ],
    ),
    (
      heading: context.tr('legal.termsSection5'),
      body: [
        context.tr('legal.termsSection5Body1'),
        context.tr('legal.termsSection5Body2'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: context.tr('legal.termsTitle'),
      icon: Icons.description_outlined,
      updated: context.tr('legal.termsUpdated'),
      sections: _sections(context),
      intro: context.tr('legal.termsIntro'),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static List<({String heading, List<String> body})> _sections(BuildContext context) => [
    (
      heading: context.tr('legal.privacySection1'),
      body: [
        context.tr('legal.privacySection1Body1'),
        context.tr('legal.privacySection1Body2'),
      ],
    ),
    (
      heading: context.tr('legal.privacySection2'),
      body: [
        context.tr('legal.privacySection2Body1'),
        context.tr('legal.privacySection2Body2'),
      ],
    ),
    (
      heading: context.tr('legal.privacySection3'),
      body: [
        context.tr('legal.privacySection3Body1'),
        context.tr('legal.privacySection3Body2'),
      ],
    ),
    (
      heading: context.tr('legal.privacySection4'),
      body: [
        context.tr('legal.privacySection4Body1'),
        context.tr('legal.privacySection4Body2', namedArgs: {'email': AppConfig.supportEmail}),
      ],
    ),
    (
      heading: context.tr('legal.privacySection5'),
      body: [
        context.tr('legal.privacySection5Body1'),
        context.tr('legal.privacySection5Body2'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: context.tr('legal.privacyTitle'),
      icon: Icons.privacy_tip_outlined,
      updated: context.tr('legal.privacyUpdated'),
      sections: _sections(context),
      intro: context.tr('legal.privacyIntro'),
    );
  }
}