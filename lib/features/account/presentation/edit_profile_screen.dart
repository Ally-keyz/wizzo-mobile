import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/account_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountRepositoryProvider);
      await repo.updateProfile({
        'fullName': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      final data = await repo.me();
      final userMap = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data;
      final updated = User.fromApi(userMap);
      await ref.read(authControllerProvider.notifier).updateUser(updated);
      if (!mounted) return;
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
        title: Text(context.tr('account.editProfile'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  user?.shortName ?? 'W',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Palette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              WTextField(
                controller: _nameController,
                label: context.tr('common.fullName'),
                hint: context.tr('account.fullNameHint'),
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('account.fullNameError') : null,
              ),
              const SizedBox(height: 14),
              WTextField(
                controller: _phoneController,
                label: context.tr('checkout.phoneField'),
                hint: context.tr('account.phoneHint'),
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
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
                      : Text(context.tr('account.saveChanges')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}