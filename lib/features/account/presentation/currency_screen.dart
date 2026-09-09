import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currencies.dart';
import '../../../core/currency/currency_controller.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/theme/app_colors.dart';

/// Lets the user pick the currency used to display every price in the app.
///
/// Mirrors the web frontend's searchable `CurrencyPicker`. The choice is
/// persisted and applied app-wide instantly.
class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  String _query = '';

  List<CurrencyDef> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kCurrencies;
    return kCurrencies
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.symbol.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _select(CurrencyDef def) async {
    final messenger = ScaffoldMessenger.of(context);
    final toast = context.tr(
      'currency.changedToast',
      namedArgs: {'currency': def.name},
    );
    await currencyController.setCurrency(def.code);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('currency.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.goldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                context.tr('currency.description'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.appColors.onGoldSoft,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.tr('currency.searchHint'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<CurrencyState>(
              valueListenable: currencyController,
              builder: (context, state, _) {
                final current = state.code;
                return RadioGroup<String>(
                  groupValue: current,
                  onChanged: (v) {
                    final def = currencyDef(v ?? current);
                    _select(def);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final def in _filtered)
                        RadioListTile<String>(
                          value: def.code,
                          activeColor: Palette.gold,
                          title: Text(
                            def.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${def.code} · ${def.symbol}'),
                          secondary: Text(
                            formatFromBase(100000, def.code, state.rates),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
