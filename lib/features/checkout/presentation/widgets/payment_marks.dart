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
    child: Image.asset(
      'assets/branding/momo-logo.png',
      width: size,
      height: size,
    ),
  );
}

class GooglePayMark extends StatelessWidget {
  const GooglePayMark({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/branding/google_pay.svg', height: height);
}

class ApplePayMark extends StatelessWidget {
  const ApplePayMark({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/branding/apple_pay.svg', height: height);
}

/// PayPal wordmark, matching the web `PayPalMark` (dark-blue "Pay" +
/// light-blue "Pal", italic heavy weight).
class PayPalMark extends StatelessWidget {
  const PayPalMark({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Pay',
          style: TextStyle(
            color: const Color(0xFF003087),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(
          text: 'Pal',
          style: TextStyle(
            color: const Color(0xFF009CDE),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
    style: TextStyle(fontSize: height, height: 1, letterSpacing: -0.4),
  );
}

/// Miniature credit card mark shown on the card payment tile.
class CardMark extends StatelessWidget {
  const CardMark({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/branding/card.svg', height: height);
}
