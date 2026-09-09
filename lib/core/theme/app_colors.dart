import 'package:flutter/material.dart';

/// Raw design tokens — a direct 1:1 mirror of `frontend/src/index.css`.
abstract class Palette {
  // Brand
  static const gold = Color(0xFFFFD60A); // --primary / accent-500
  static const goldDark = Color(0xFFE6BF00); // accent-600 (pressed)
  static const navy = Color(0xFF0B0E1A); // splash / charts

  // Light mode
  static const lightBackground = Color(0xFFFFFFFF); // --background
  static const lightCard = Color(0xFFFFFFFF); // --card
  static const lightForeground = Color(0xFF18181B); // --foreground
  static const lightMuted = Color(0xFFF4F4F5); // --muted
  static const lightMutedForeground = Color(0xFF71717A); // --muted-foreground
  static const lightBorder = Color(0xFFE4E4E7); // --border / --input
  static const lightDestructive = Color(0xFFEF4444); // --destructive
  static const lightRing = Color(0xFFFFD60A); // --ring
  static const lightSuccess = Color(0xFF22C55E); // --success
  static const lightWarning = Color(0xFFEAB308); // --warning

  // Dark mode
  static const darkBackground = Color(0xFF18181B);
  static const darkCard = Color(0xFF27272A);
  static const darkForeground = Color(0xFFFAFAFA);
  static const darkMuted = Color(0xFF27272A);
  static const darkMutedForeground = Color(0xFFA1A1AA);
  static const darkBorder = Color(0xFF3F3F46);
  static const darkDestructive = Color(0xFFDC2626);
  static const darkSuccess = Color(0xFF22C55E);
  static const darkWarning = Color(0xFFEAB308);

  // Verified / info accent (not a web token — canonicalised for mobile).
  static const infoBlue = Color(0xFF3B82F6);
  static const infoBlueBright = Color(0xFF60A5FA);
}

/// Semantic colors that aren't represented by Material's ColorScheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.gold,
    required this.goldSoft,
    required this.onGoldSoft,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color gold;
  final Color goldSoft;
  final Color onGoldSoft;

  static const light = AppColors(
    success: Palette.lightSuccess,
    onSuccess: Colors.white,
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    info: Palette.infoBlue,
    onInfo: Colors.white,
    infoContainer: Color(0xFFDBEAFE),
    onInfoContainer: Color(0xFF1E3A8A),
    warning: Palette.lightWarning,
    onWarning: Color(0xFF052E16),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    gold: Palette.gold,
    goldSoft: Color(0xFFFFF8C4),
    onGoldSoft: Color(0xFF4D4000),
  );

  static const dark = AppColors(
    success: Palette.darkSuccess,
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14532D),
    onSuccessContainer: Color(0xFFBBF7D0),
    info: Palette.infoBlueBright,
    onInfo: Color(0xFF05202F),
    infoContainer: Color(0xFF1E3A8A),
    onInfoContainer: Color(0xFF93C5FD),
    warning: Color(0xFFFACC15),
    onWarning: Color(0xFF422006),
    warningContainer: Color(0xFF3A3200),
    onWarningContainer: Color(0xFFFDE047),
    gold: Palette.gold,
    goldSoft: Color(0xFF3A3200),
    onGoldSoft: Color(0xFFFFE047),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? gold,
    Color? goldSoft,
    Color? onGoldSoft,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      onGoldSoft: onGoldSoft ?? this.onGoldSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      onGoldSoft: Color.lerp(onGoldSoft, other.onGoldSoft, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}