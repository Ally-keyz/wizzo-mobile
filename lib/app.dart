import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 1. Added this import for SystemUiOverlayStyle
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/currency/currency_controller.dart';
import 'core/i18n/rw_fallback_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/cookie_consent.dart';
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
      builder: (context, _, __) => MaterialApp.router(
        title: 'Wizzo Market',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        themeMode: themeMode,
        
        // 2. Updated light theme with transparent status bar background + black text
        theme: buildLightTheme().copyWith(
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,        // Completely removes the status bar background (Android)
              statusBarIconBrightness: Brightness.dark,   // Black icons for Android
              statusBarBrightness: Brightness.light,      // Black icons for iOS
            ),
          ),
        ),
        
        // 3. Updated dark theme with transparent status bar background + white text
        darkTheme: buildDarkTheme().copyWith(
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,        // Completely removes the status bar background (Android)
              statusBarIconBrightness: Brightness.light,  // White icons for Android
              statusBarBrightness: Brightness.dark,       // White icons for iOS
            ),
          ),
        ),

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
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const CookieConsentBanner(),
          ],
        ),
      ),
    );
  }
}
