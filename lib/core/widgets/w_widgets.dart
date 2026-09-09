import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Red numeric badge used on nav / bell / message icons.
class WBadge extends StatelessWidget {
  const WBadge({super.key, required this.count, this.offset = 0});

  final int count;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Section title with optional trailing action.
class WSectionHeader extends StatelessWidget {
  const WSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.showViewAll = true,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showViewAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (showViewAll && actionLabel != null)
            GestureDetector(
              onTap: onAction ?? () {},
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Section header used on list screens with a plain back-less title.
class WPageTitle extends StatelessWidget {
  const WPageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Standard labelled input used across auth and checkout forms.
class WTextField extends StatelessWidget {
  const WTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          enabled: enabled,
          autofillHints: autofillHints,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Pill-style tappable chip.
class WChip extends StatelessWidget {
  const WChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = selected ? Colors.black : scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Palette.gold : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? Palette.gold : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder with optional action.
class WEmptyState extends StatelessWidget {
  const WEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ticking countdown label.
class WCountdown extends StatefulWidget {
  const WCountdown(this.endsAt, {super.key, this.light = false});
  final DateTime? endsAt;
  final bool light;

  @override
  State<WCountdown> createState() => _WCountdownState();
}

class _WCountdownState extends State<WCountdown> {
  late DateTime? _endsAt = widget.endsAt;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _endsAt = widget.endsAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _endsAt == null
        ? '00:00:00'
        : () {
            var diff = _endsAt!.difference(DateTime.now());
            if (diff.isNegative) diff = Duration.zero;
            final h = diff.inHours;
            final m = diff.inMinutes % 60;
            final s = diff.inSeconds % 60;
            final d = h ~/ 24;
            if (d > 0) {
              return '${d}d ${(h % 24).toString().padLeft(2, '0')}:'
                  '${m.toString().padLeft(2, '0')}';
            }
            return '${h.toString().padLeft(2, '0')}:'
                '${m.toString().padLeft(2, '0')}:'
                '${s.toString().padLeft(2, '0')}';
          }();

    if (remaining == '00:00:00') {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() {});
      });
    }

    final color = widget.light ? Colors.white : context.appColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          remaining,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Bare brand icon (no box/background), for top-right auth screen corners.
class WAppMark extends StatelessWidget {
  const WAppMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo_icon.png',
      width: size,
      height: size,
    );
  }
}

/// Small horizontal progress bars used by the sign-up wizards.
class WStepBars extends StatelessWidget {
  const WStepBars({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i <= index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 28,
          height: 4,
          decoration: BoxDecoration(
            color: active ? Palette.gold : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Horizontal step indicator (Placed → Confirmed → …).
///
/// Renders the steps as a grid of two per row with a "rope" line running
/// through each row so long labels never overflow narrow screens.
class WStepIndicator extends StatelessWidget {
  const WStepIndicator({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 0,
      childAspectRatio: 1.35,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepCell(
            label: steps[i],
            index: i,
            current: current,
            scheme: scheme,
          ),
      ],
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({
    required this.label,
    required this.index,
    required this.current,
    required this.scheme,
  });

  final String label;
  final int index;
  final int current;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isDone = index < current;
    final isCurrent = index == current;

    return Column(
      children: [
        SizedBox(
          height: 34,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  color: isDone ? Palette.gold : scheme.outlineVariant,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent || isDone
                      ? Palette.gold
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    width: isCurrent ? 3 : 1,
                    color: isCurrent
                        ? scheme.onSurface
                        : isDone
                            ? Palette.gold
                            : scheme.outlineVariant,
                  ),
                ),
                child: isCurrent || isDone
                    ? (isDone
                        ? const Icon(Icons.check, size: 18, color: Colors.black)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ))
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              color: isCurrent
                  ? scheme.onSurface
                  : isDone
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
