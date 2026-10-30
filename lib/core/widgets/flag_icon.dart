import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a country flag SVG from the bundled flag set.
///
/// [countryCode] is ISO 3166-1 alpha-2 (any case), e.g. `rw`, `us`, `eu`.
///
/// Only the flags for supported currencies and UI languages are bundled (see
/// `assets/flags/supported/`); anything else falls back to the neutral `xx`
/// flag so a missing file can never crash a picker.
class FlagIcon extends StatelessWidget {
  const FlagIcon({super.key, required this.countryCode, this.width = 20});

  final String countryCode;
  final double width;

  @override
  Widget build(BuildContext context) {
    final code = countryCode.trim().toLowerCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SvgPicture.asset(
        'assets/flags/supported/$code.svg',
        width: width,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => SizedBox(width: width, height: width * 0.75),
        errorBuilder: (_, _, _) => SvgPicture.asset(
          'assets/flags/supported/xx.svg',
          width: width,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
