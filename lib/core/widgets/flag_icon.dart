import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a country flag SVG from the bundled flag-icons set.
///
/// [countryCode] is ISO 3166-1 alpha-2 (any case), e.g. `rw`, `us`, `eu`.
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
        'assets/flags/4x3/$code.svg',
        width: width,
        fit: BoxFit.cover,
        placeholderBuilder: (_) =>
            SizedBox(width: width, height: width * 0.75),
      ),
    );
  }
}
