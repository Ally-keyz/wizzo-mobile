import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/w_image.dart';
import '../../../cart/models/cart.dart';
import '../../models/checkout.dart';

/// Shows the seller's pay-in details for a manual payment — the mobile
/// equivalent of the web checkout `PaymentInstructions` component.
class PaymentInstructionsCard extends StatelessWidget {
  const PaymentInstructionsCard({
    super.key,
    required this.method,
    this.account,
    this.amount,
  });

  final PaymentKind method;
  final SellerPaymentAccount? account;
  final num? amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    if (method == PaymentKind.googlePay) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.infoContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 18, color: colors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Google Pay will charge your saved card when you place the order. No extra steps needed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (method == PaymentKind.cashOnDelivery) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.successContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_outlined, size: 18, color: colors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(
                  'common.payCashOnDelivery',
                  namedArgs: {
                    'details': amount != null
                        ? ' (${formatMoney(amount)})'
                        : '',
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (account == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.warningContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined, size: 18, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(
                  'common.noAccountListed',
                  namedArgs: {
                    'type': method == PaymentKind.momo
                        ? context.tr('common.mobileMoney')
                        : context.tr('common.bank'),
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isMomo = method == PaymentKind.momo;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_outlined, size: 16, color: Palette.gold),
              const SizedBox(width: 6),
              Text(
                context.tr('common.sendPaymentTo'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (amount != null)
                Text(
                  formatMoney(amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Palette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (account!.provider != null && account!.provider!.isNotEmpty) ...[
            Text(
              account!.provider!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Palette.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          _row(theme, context.tr('common.accountName'), account!.accountName),
          const SizedBox(height: 4),
          _row(
            theme,
            isMomo
                ? context.tr('common.phoneNumber')
                : context.tr('common.accountNumber'),
            account!.accountNumber,
            mono: true,
          ),
          if (account!.instructions != null &&
              account!.instructions!.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    account!.instructions!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.tr('common.attachReceiptHint'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal step indicator (Cart → Shipping → Payment → Review).
class CheckoutStepIndicator extends StatelessWidget {
  const CheckoutStepIndicator({
    super.key,
    required this.current,
    required this.labels,
  });

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _circle(context, theme, i),
            if (i < labels.length - 1) _line(context, theme, i),
          ],
        ],
      ),
    );
  }

  Widget _circle(BuildContext context, ThemeData theme, int i) {
    final done = i < current;
    final active = i == current;
    final Color color;
    final Color fg;
    if (done) {
      color = context.appColors.success;
      fg = Colors.white;
    } else if (active) {
      color = Palette.gold;
      fg = Colors.black;
    } else {
      color = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[i],
            style: theme.textTheme.labelSmall?.copyWith(
              color: active
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, ThemeData theme, int i) {
    final filled = i < current;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 22),
        color: filled
            ? context.appColors.success
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}

/// Generic rounded summary card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// Seller breakdown line in the cart step.
class CheckoutGroupLine extends StatelessWidget {
  const CheckoutGroupLine({super.key, required this.group});

  final CartSellerGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: group.sellerName ?? context.tr('common.seller'),
      trailing: Text(
        formatMoney(group.subtotal),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Palette.gold,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: WImage(
                      url: item.product.images.isNotEmpty
                          ? item.product.images.first
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item.product.name} Ã— ${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatMoney(item.lineTotal),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Radio-style payment method tile.
class CheckoutPaymentTile extends StatelessWidget {
  const CheckoutPaymentTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.goldSoft
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Palette.gold : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              switch (option.kind) {
                PaymentKind.momo => Icons.phone_android_outlined,
                PaymentKind.googlePay => Icons.account_balance_wallet_outlined,
                PaymentKind.bank => Icons.account_balance_outlined,
                PaymentKind.cashOnDelivery => Icons.payments_outlined,
              },
              color: selected
                  ? context.appColors.onGoldSoft
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    option.providers.join(', '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Palette.gold : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutSummaryRow extends StatelessWidget {
  const CheckoutSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style:
                (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: valueColor ?? theme.colorScheme.onSurface,
                    ),
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom navigation between steps / place order.
class CheckoutBottomNav extends StatelessWidget {
  const CheckoutBottomNav({
    super.key,
    required this.step,
    this.last = false,
    this.busy = false,
    required this.label,
    this.onBack,
    required this.onContinue,
  });

  final int step;
  final bool last;
  final bool busy;
  final String label;
  final VoidCallback? onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoBack = step > 0 && onBack != null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (canGoBack) ...[
            OutlinedButton(
              onPressed: onBack,
              child: Text(context.tr('common.back')),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onContinue,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(last ? label : context.tr('common.continue')),
            ),
          ),
        ],
      ),
    );
  }
}
