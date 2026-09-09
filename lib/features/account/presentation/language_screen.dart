import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_colors.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String? _lang;

  static const _languages = <({String code, String native, String labelKey})>[
    (code: 'en', native: 'English', labelKey: 'language.english'),
    (code: 'fr', native: 'Français', labelKey: 'language.french'),
    (code: 'rw', native: 'Kinyarwanda', labelKey: 'language.kinyarwanda'),
    (code: 'de', native: 'Deutsch', labelKey: 'language.german'),
    (code: 'sw', native: 'Kiswahili', labelKey: 'language.swahili'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLang = _lang ?? context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('language.label'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              context.tr('language.description'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.onGoldSoft,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final lang in _languages)
            RadioListTile<String>(
              value: lang.code,
              groupValue: currentLang,
              activeColor: Palette.gold,
              title: Text(
                lang.native,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(context.tr(lang.labelKey)),
              onChanged: (v) async {
                if (v == null) return;
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _lang = v);
                await context.setLocale(Locale(v));
                await AppPrefs.setLanguage(v);
                if (!context.mounted) return;
                messenger
                  ..removeCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          'language.changedToast',
                          namedArgs: {'language': context.tr(lang.labelKey)},
                        ),
                      ),
                    ),
                  );
              },
            ),
        ],
      ),
    );
  }
}
