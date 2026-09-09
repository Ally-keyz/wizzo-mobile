import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/currency/currency_controller.dart';
import 'core/i18n/rw_fallback_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/messages/providers/chat_providers.dart';
import 'features/settings/theme_provider.dart';

class WizzoApp extends ConsumerWidget {
  const WizzoApp({super.key});

  static const _easyLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
    Locale('de'),
    Locale('sw'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Keeps the chat socket alive and connected while the user is signed in.
    ref.watch(chatSocketLifecycleProvider);

    // Rebuilds the whole tree when the display currency changes so every
    // price switches instantly (like the web re-rendering on store change).
    return ValueListenableBuilder<CurrencyState>(
      valueListenable: currencyController,
      builder: (context, _, _) => MaterialApp.router(
        title: 'Wizzo Market',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        themeMode: themeMode,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        // Flutter's bundled Material/Cupertino localizations do not ship a
        // Kinyarwanda (rw) locale, so the fallback delegates appended below are
        // the only ones that support rw. They load English stock strings while
        // easy_localization keeps translating app text, preventing the
        // "No MaterialLocalizations found" / "locale not supported" errors.
        localizationsDelegates: [
          ...context.localizationDelegates,
          const RWMaterialLocalizationsDelegate(_easyLocales),
          const RWCupertinoLocalizationsDelegate(_easyLocales),
        ],
        supportedLocales: _easyLocales,
        locale: context.locale,
      ),
    );
  }
}
