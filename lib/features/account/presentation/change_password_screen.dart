import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('account.passwordChanged'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required ValueChanged<bool> onToggle,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    Iterable<String>? autofillHints,
  }) {
    return WTextField(
      controller: controller,
      label: label,
      obscure: obscure,
      textInputAction: textInputAction,
      prefixIcon: Icons.lock_outline,
      autofillHints: autofillHints,
      validator: validator,
      suffix: IconButton(
        onPressed: () => onToggle(!obscure),
        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('account.changePassword'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
                    Icon(Icons.shield_outlined, color: context.appColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('account.passwordIntro'),
                        style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.onInfoContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _passwordField(
                label: context.tr('account.currentPassword'),
                controller: _currentController,
                obscure: _showCurrent,
                onToggle: (v) => setState(() => _showCurrent = v),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v == null || v.isEmpty) ? context.tr('account.currentPasswordError') : null,
              ),
              const SizedBox(height: 14),
              _passwordField(
                label: context.tr('common.newPassword'),
                controller: _newController,
                obscure: _showNew,
                onToggle: (v) => setState(() => _showNew = v),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v == null || v.isEmpty) return context.tr('account.newPasswordError');
                  if (v.length < 8) return context.tr('account.passwordLengthError');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _passwordField(
                label: context.tr('account.confirmPassword'),
                controller: _confirmController,
                obscure: _showConfirm,
                onToggle: (v) => setState(() => _showConfirm = v),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v == null || v.isEmpty) return context.tr('account.reEnterPassword');
                  if (v != _newController.text) return context.tr('account.passwordMismatch');
                  return null;
                },
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
                      : Text(context.tr('account.updatePassword')),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('account.staySignedIn'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}