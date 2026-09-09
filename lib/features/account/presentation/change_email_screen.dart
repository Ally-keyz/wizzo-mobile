import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = ref.read(authControllerProvider).user?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final newEmail = _emailController.text.trim();
    try {
      await ref
          .read(authRepositoryProvider)
          .changeEmail(
            currentPassword: _passwordController.text,
            newEmail: newEmail,
          );
      final current = ref.read(authControllerProvider).user;
      if (current != null) {
        await ref
            .read(authControllerProvider.notifier)
            .updateUser(current.copyWith(email: newEmail, emailVerified: false));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('account.emailChanged'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('account.changeEmail'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.infoContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_outlined, color: context.appColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('account.signedInAs', namedArgs: {
                          'email': user?.email ?? context.tr('account.unknownFallback'),
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.onInfoContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              WTextField(
                controller: _emailController,
                label: context.tr('account.newEmail'),
                hint: context.tr('account.newEmailHint'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  final email = v?.trim() ?? '';
                  if (email.isEmpty) return context.tr('account.newEmailRequired');
                  if (!email.contains('@')) return context.tr('account.newEmailInvalid');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              WTextField(
                controller: _passwordController,
                label: context.tr('account.confirmWithPassword'),
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v == null || v.isEmpty) ? context.tr('account.currentPasswordError') : null,
                suffix: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appColors.warningContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_error}',
                    style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.onWarningContainer),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(context.tr('account.changeEmailButton')),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('account.emailVerificationNote'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}