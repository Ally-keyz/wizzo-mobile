import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ColorScheme _lightScheme() => const ColorScheme.light(
  primary: Palette.gold,
  onPrimary: Colors.black,
  primaryContainer: Color(0xFFFFF8C4),
  onPrimaryContainer: Color(0xFF4D4000),
  secondary: Color(0xFF71717A),
  onSecondary: Colors.white,
  secondaryContainer: Palette.lightMuted,
  onSecondaryContainer: Palette.lightForeground,
  tertiary: Palette.infoBlue,
  onTertiary: Colors.white,
  surface: Palette.lightCard,
  onSurface: Palette.lightForeground,
  onSurfaceVariant: Palette.lightMutedForeground,
  surfaceContainerHighest: Color(0xFFF0F0F2),
  outline: Palette.lightBorder,
  outlineVariant: Color(0xFFEEEEF0),
  error: Palette.lightDestructive,
  onError: Colors.white,
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF7F1D1D),
  shadow: Color(0x14000000),
  scrim: Colors.black,
  inverseSurface: Palette.lightForeground,
  inversePrimary: Palette.navy,
);

ColorScheme _darkScheme() => const ColorScheme.dark(
  primary: Palette.gold,
  onPrimary: Colors.black,
  primaryContainer: Color(0xFF403600),
  onPrimaryContainer: Color(0xFFFFE047),
  secondary: Color(0xFFA1A1AA),
  onSecondary: Color(0xFF18181B),
  secondaryContainer: Palette.darkMuted,
  onSecondaryContainer: Palette.darkForeground,
  tertiary: Palette.infoBlueBright,
  onTertiary: Color(0xFF05202F),
  surface: Palette.darkCard,
  onSurface: Palette.darkForeground,
  onSurfaceVariant: Palette.darkMutedForeground,
  surfaceContainerHighest: Color(0xFF2E2E32),
  outline: Palette.darkBorder,
  outlineVariant: Color(0xFF333338),
  error: Palette.darkDestructive,
  onError: Colors.white,
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFCA5A5),
  shadow: Color(0x40000000),
  scrim: Colors.black,
  inverseSurface: Palette.darkForeground,
  inversePrimary: Palette.goldDark,
);

TextTheme _textTheme(ColorScheme scheme) {
  final base = ThemeData(brightness: scheme.brightness).textTheme;
  final body = GoogleFonts.interTextTheme(
    base,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final display = GoogleFonts.poppinsTextTheme(body);

  return display.copyWith(
    displayLarge: body.displayLarge,
    displayMedium: body.displayMedium,
    displaySmall: body.displaySmall,
    headlineLarge: display.headlineLarge,
    headlineMedium: display.headlineMedium,
    headlineSmall: display.headlineSmall?.copyWith(fontSize: 20),
    titleLarge: display.titleLarge?.copyWith(fontSize: 18),
    titleMedium: display.titleMedium,
    titleSmall: display.titleSmall,
  );
}

ThemeData _base(ColorScheme scheme, AppColors appColors) {
  final textTheme = _textTheme(scheme);
  final isDark = scheme.brightness == Brightness.dark;
  final inputRadius = 14.0;

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: scheme.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: textTheme,
    extensions: [appColors],
    primaryColor: Palette.gold,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),

    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? scheme.surface : const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: Palette.gold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Palette.gold.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.black.withValues(alpha: 0.6),
        minimumSize: const Size(0, 52),
        shape: buttonShape,
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(0, 52),
        shape: buttonShape,
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: scheme.secondaryContainer,
      selectedColor: Palette.gold,
      labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? scheme.surfaceContainerHighest
          : scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? scheme.onSurface : Colors.white,
      ),
      actionTextColor: Palette.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Palette.gold,
      linearTrackColor: scheme.outlineVariant,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: Palette.gold,
      labelStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      dividerColor: Colors.transparent,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: Palette.gold.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
    ),
  );
}

ThemeData buildLightTheme() => _base(_lightScheme(), AppColors.light);

ThemeData buildDarkTheme() => _base(_darkScheme(), AppColors.dark);
