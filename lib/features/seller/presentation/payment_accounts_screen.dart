import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/w_async.dart';
import '../data/seller_repository.dart';
import '../models/payment_account.dart';
import '../providers/seller_providers.dart';

/// Add / edit / remove the store's payment accounts (max 10).
class PaymentAccountsScreen extends ConsumerStatefulWidget {
  const PaymentAccountsScreen({super.key});

  @override
  ConsumerState<PaymentAccountsScreen> createState() =>
      _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends ConsumerState<PaymentAccountsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('seller.paymentAccounts'))),
      body: WAsyncView(
        value: storeAsync,
        onRetry: () => ref.invalidate(myStoreProvider),
        builder: (context, store) {
          final accounts = store?.paymentAccounts ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        account.method == PaymentMethodKind.mobileMoney
                            ? Icons.phone_android
                            : account.method == PaymentMethodKind.bank
                            ? Icons.account_balance_outlined
                            : Icons.payments_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(account.method.label(context)),
                      subtitle: Text(
                        [
                          if (account.provider != null &&
                              account.provider!.isNotEmpty)
                            account.provider,
                          account.accountNumber,
                          account.accountName,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.tr('common.edit'),
                            onPressed: () => _edit(context, accounts, account),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: context.tr('common.delete'),
                            onPressed: () =>
                                _remove(context, accounts, account),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (accounts.length < 10)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(context, accounts, null),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('seller.addPaymentAccount')),
                  ),
                ),
              if (_saving) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                context.tr('seller.paymentAccountsHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _edit(
    BuildContext context,
    List<PaymentAccount> accounts,
    PaymentAccount? existing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AccountSheet(
        existing: existing,
        onSave: (account) async {
          final updated = [
            for (final a in accounts) identical(a, existing) ? account : a,
            if (existing == null) account,
          ];
          await _save(updated);
        },
      ),
    );
  }

  void _remove(
    BuildContext context,
    List<PaymentAccount> accounts,
    PaymentAccount account,
  ) async {
    final updated = accounts.where((a) => !identical(a, account)).toList();
    try {
      await ref.read(sellerRepositoryProvider).updatePaymentAccounts(updated);
      ref.invalidate(myStoreProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('seller.paymentAccountRemoved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _save(List<PaymentAccount> accounts) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .updatePaymentAccounts(accounts.take(10).toList());
      if (mounted) {
        ref.invalidate(myStoreProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('seller.paymentAccountsSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.existing, required this.onSave});

  final PaymentAccount? existing;
  final Future<void> Function(PaymentAccount) onSave;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late PaymentMethodKind _method;
  final _provider = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _instructions = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _method = e?.method ?? PaymentMethodKind.mobileMoney;
    _provider.text = e?.provider ?? '';
    _accountName.text = e?.accountName ?? _accountName.text;
    _accountNumber.text = e?.accountNumber ?? _accountNumber.text;
    _instructions.text = e?.instructions ?? '';
  }

  @override
  void dispose() {
    _provider.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _instructions.dispose();
    super.dispose();
  }

  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                widget.existing == null
                    ? 'seller.addPaymentAccount'
                    : 'seller.editPaymentAccount',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final method in PaymentMethodKind.values)
                  ChoiceChip(
                    label: Text(method.label(context)),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                    selectedColor: _cs.primary,
                    labelStyle: TextStyle(
                      color: _method == method
                          ? _cs.onPrimary
                          : _cs.onSurfaceVariant,
                      fontWeight: _method == method
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_method != PaymentMethodKind.cashOnDelivery) ...[
              TextField(
                controller: _provider,
                decoration: InputDecoration(
                  labelText: _method == PaymentMethodKind.mobileMoney
                      ? context.tr('seller.providerLabel')
                      : context.tr('seller.bankName'),
                  hintText: _method == PaymentMethodKind.mobileMoney
                      ? context.tr('seller.providerHint')
                      : context.tr('seller.bankNameHint'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.store_mall_directory_outlined),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _accountName,
              decoration: InputDecoration(
                labelText: context.tr('seller.accountName'),
                hintText: context.tr('seller.accountNameHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _accountNumber,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _method == PaymentMethodKind.mobileMoney
                    ? context.tr('seller.momoNumber')
                    : context.tr('seller.accountNumber'),
                hintText: context.tr('seller.accountNumberHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _instructions,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('seller.instructionsLabel'),
                hintText: context.tr('seller.instructionsHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('seller.saveAccount')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_accountName.text.trim().isEmpty ||
        _accountNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('seller.errorAccountFieldsRequired')),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final account = PaymentAccount(
      method: _method,
      provider: _method == PaymentMethodKind.cashOnDelivery
          ? null
          : _provider.text,
      accountName: _accountName.text.trim(),
      accountNumber: _accountNumber.text.trim(),
      instructions: _instructions.text,
    );
    try {
      await widget.onSave(account);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
