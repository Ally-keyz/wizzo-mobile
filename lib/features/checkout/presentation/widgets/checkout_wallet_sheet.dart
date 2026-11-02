import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/checkout.dart';
import 'checkout_shared.dart';
import 'payment_marks.dart';

/// What the wallet modal asks the checkout screen to do after it closes.
enum WalletSheetAction {
  /// The native wallet confirmed the PaymentIntent; verify it server-side.
  paid,

  /// Native wallet pay is unavailable (or failed); open Stripe's hosted
  /// checkout page, which still offers Google Pay / Apple Pay on the web.
  hostedCheckout,
}

/// Modal that shows Stripe's own Google Pay / Apple Pay button. The button is
/// rendered by the Stripe SDK (`PlatformPayButton`), not by a hand-built wallet
/// integration, so the native sheet and the resulting payment method are both
/// owned by Stripe.
class CheckoutWalletSheet extends StatefulWidget {
  const CheckoutWalletSheet({
    super.key,
    required this.wallet,
    required this.clientSecret,
    required this.currencyCode,
    required this.amount,
    required this.supported,
    required this.testMode,
  });

  final PaymentKind wallet;
  final String clientSecret;
  final String currencyCode;
  final num amount;

  /// False when the device cannot present the native wallet sheet. The sheet
  /// then explains the limitation and offers Stripe's hosted checkout instead.
  final bool supported;
  final bool testMode;

  @override
  State<CheckoutWalletSheet> createState() => _CheckoutWalletSheetState();
}

class _CheckoutWalletSheetState extends State<CheckoutWalletSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final currencyCode = widget.currencyCode.toUpperCase();
      if (widget.wallet == PaymentKind.applePay) {
        await Stripe.instance.confirmPlatformPayPaymentIntent(
          clientSecret: widget.clientSecret,
          confirmParams: PlatformPayConfirmParams.applePay(
            applePay: ApplePayParams(
              merchantCountryCode: AppConfig.stripeMerchantCountry,
              currencyCode: currencyCode,
              cartItems: [
                ApplePayCartSummaryItem.immediate(
                  label: AppConfig.appName,
                  amount: _walletAmount(widget.amount, currencyCode),
                ),
              ],
            ),
          ),
        );
      } else {
        await Stripe.instance.confirmPlatformPayPaymentIntent(
          clientSecret: widget.clientSecret,
          confirmParams: PlatformPayConfirmParams.googlePay(
            googlePay: GooglePayParams(
              merchantCountryCode: AppConfig.stripeMerchantCountry,
              currencyCode: currencyCode,
              merchantName: AppConfig.appName,
              testEnv: widget.testMode,
            ),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(WalletSheetAction.paid);
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code == FailureCode.Canceled) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _error = _failureMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  String _failureMessage(StripeException error) {
    final wallet = paymentKindLabel(context, widget.wallet);
    final detail = error.error.localizedMessage?.trim().isNotEmpty == true
        ? error.error.localizedMessage!.trim()
        : error.error.message?.trim();
    final base = context.tr(
      'checkout.payment.walletFailed',
      namedArgs: {'wallet': wallet},
    );
    return detail == null || detail.isEmpty ? base : '$base\n\n$detail';
  }

  /// Apple Pay wants a decimal amount string, without minor units.
  String _walletAmount(num amount, String currency) {
    const zeroDecimal = {'JPY'};
    if (zeroDecimal.contains(currency.toUpperCase())) {
      return amount.round().toString();
    }
    return amount.toStringAsFixed(2);
  }

  String _money(num amount, String currency) {
    return NumberFormat.simpleCurrency(
      name: currency.toUpperCase(),
      locale: 'en',
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final wallet = paymentKindLabel(context, widget.wallet);
    final isApplePay = widget.wallet == PaymentKind.applePay;
    final mark = isApplePay
        ? ApplePayMark(height: 26)
        : GooglePayMark(height: 26);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  mark,
                  const Spacer(),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: context.tr('common.cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'checkout.payment.walletSheetTitle',
                  namedArgs: {'wallet': wallet},
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _money(widget.amount, widget.currencyCode),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'checkout.payment.walletSheetHint',
                  namedArgs: {'wallet': wallet},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (widget.supported) ...[
                SizedBox(
                  height: 52,
                  child: IgnorePointer(
                    ignoring: _busy,
                    child: PlatformPayButton(
                      onPressed: _confirm,
                      type: PlatformButtonType.plain,
                      appearance: PlatformButtonStyle.black,
                      borderRadius: 12,
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ] else
                _WalletNotice(
                  icon: Icons.info_outline,
                  message: context.tr(
                    'checkout.payment.walletSheetUnavailable',
                    namedArgs: {'wallet': wallet},
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _WalletNotice(
                  icon: Icons.error_outline,
                  color: theme.colorScheme.error,
                  background: theme.colorScheme.errorContainer,
                  message: _error!,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(WalletSheetAction.hostedCheckout),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  context.tr('checkout.payment.walletCheckoutFallback'),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: colors.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.tr('checkout.payment.walletStripeNote'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletNotice extends StatelessWidget {
  const _WalletNotice({
    required this.icon,
    required this.message,
    this.color,
    this.background,
  });

  final IconData icon;
  final String message;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            background ??
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
