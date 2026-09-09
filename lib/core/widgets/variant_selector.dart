import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pill-style single-choice option selector (size/color). Used on the product
/// detail screen and reused by the shorts quick-add sheet so every variant
/// picker in the app looks and behaves identically.
class VariantSelector extends StatelessWidget {
  const VariantSelector({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onSelect,
  });

  final String title;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = option == value;
            return GestureDetector(
              onTap: () => onSelect(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Palette.gold : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Palette.gold : theme.colorScheme.outline,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.black : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}