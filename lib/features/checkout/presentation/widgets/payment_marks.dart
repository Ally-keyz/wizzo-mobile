import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Brand marks for the payment tiles, mirroring the web
/// `components/payments/PaymentMarks` component.

class MomoMark extends StatelessWidget {
  const MomoMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset('assets/branding/momo-logo.png', width: size, height: size),
      );
}

class GooglePayMark extends StatelessWidget {
  const GooglePayMark({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/branding/google_pay.svg',
        height: height,
      );
}

class ApplePayMark extends StatelessWidget {
  const ApplePayMark({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/branding/apple_pay.svg',
        height: height,
      );
}

/// Miniature credit card mark shown on the card payment tile.
class CardMark extends StatelessWidget {
  const CardMark({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/branding/card.svg',
        height: height,
      );
}
