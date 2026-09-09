import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../providers/auth_provider.dart';

/// Two-step customer sign-up, mirroring the web `/sign-up/customer` wizard.
class BuyerSignUpScreen extends ConsumerStatefulWidget {
  const BuyerSignUpScreen({super.key});

  @override
  ConsumerState<BuyerSignUpScreen> createState() => _BuyerSignUpScreenState();
}

class _BuyerSignUpScreenState extends ConsumerState<BuyerSignUpScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).google();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _fullName.text,
            email: _email.text,
            password: _password.text,
          );
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  void _next() {
    setState(() {
      _error = null;
      final nameError = Validators.fullName(_fullName.text);
      final emailError = Validators.email(_email.text);
      if (nameError != null || emailError != null) {
        _error = localizeError(context, nameError ?? emailError!);
        return;
      }
      _step = 1;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: WAppMark(size: 40)),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('auth.signUp.title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('auth.signUp.tagline'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_step == 0) ...[
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const _GoogleIcon(),
                          label: Text(context.tr('auth.google.cta')),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                context.tr('auth.signUp.orSignUpWithEmail'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        WTextField(
                          controller: _fullName,
                          label: context.tr('common.fullName'),
                          hint: context.tr('common.fullNameHint'),
                          prefixIcon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        WTextField(
                          controller: _email,
                          label: context.tr('common.emailAddress'),
                          hint: 'you@example.com',
                          prefixIcon: Icons.alternate_email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            InkWell(
                              onTap: _back,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _email.text,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        WTextField(
                          controller: _password,
                          label: context.tr('common.password'),
                          hint: context.tr('common.passwordHint'),
                          prefixIcon: Icons.lock_outline,
                          obscure: !_showPassword,
                          textInputAction: TextInputAction.next,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        WTextField(
                          controller: _confirm,
                          label: context.tr('common.confirmPassword'),
                          hint: context.tr('common.confirmPasswordHint'),
                          prefixIcon: Icons.lock_outline,
                          obscure: !_showPassword,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('common.termsSignUp'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : _step == 0
                              ? _next
                              : _submit,
                          child: _busy
                              ? const WInlineLoader()
                              : Text(
                                  _step == 0
                                      ? context.tr('common.continueLabel')
                                      : context.tr('common.createAccountTitle'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      WStepBars(count: 2, index: _step),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('common.alreadyHaveAccount'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(context.tr('common.signIn')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 8,
              child: IconButton(
                onPressed: _step > 0 ? _back : () => context.go('/role-choice'),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
      child: const Icon(Icons.g_mobiledata, size: 18, color: Color(0xFF4285F4)),
    );
  }
}
