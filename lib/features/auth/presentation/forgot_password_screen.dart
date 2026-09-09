import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Step { email, otp, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _otpFields = List.generate(6, (_) => TextEditingController());

  _Step _step = _Step.email;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _newPassword.dispose();
    for (final c in _otpFields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    final emailError = Validators.email(_email.text);
    if (emailError != null) {
      setState(() => _error = localizeError(context, emailError));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.otp;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('common.errors.codeResent')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  String _otpValue() => _otpFields.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final code = _otpValue();
    if (code.length < 6) {
      setState(() => _error = context.tr('common.errors.enterSixDigitCode'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // A lightweight local check before the reset call; no dedicated verify endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _busy = false;
        _step = _Step.reset;
      });
    }
  }

  Future<void> _reset() async {
    final passError = Validators.password(_newPassword.text);
    if (passError != null) {
      setState(() => _error = localizeError(context, passError));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: _email.text,
            otp: _otpValue(),
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('common.errors.passwordUpdated')),
        ),
      );
      context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _step == _Step.reset;

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(padding: EdgeInsets.only(right: 20), child: WAppMark()),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    isLast ? Icons.lock_reset : Icons.mark_email_read_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    switch (_step) {
                      _Step.email => context.tr('auth.forgot.title'),
                      _Step.otp => context.tr('auth.forgot.otpTitle'),
                      _Step.reset => context.tr('auth.forgot.resetTitle'),
                    },
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (_step) {
                      _Step.email => context.tr('auth.forgot.subtitle'),
                      _Step.otp => context.tr(
                          'auth.seller.weSentCode',
                          namedArgs: {'email': _email.text},
                        ),
                      _Step.reset => context.tr('auth.forgot.resetSubtitle'),
                    },
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_step == _Step.email) ...[
                    WTextField(
                      controller: _email,
                      label: context.tr('common.emailAddress'),
                      hint: 'you@example.com',
                      prefixIcon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ] else if (_step == _Step.otp) ...[
                    _OtpBoxes(fields: _otpFields),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _resend,
                        child: Text(
                          _busy
                              ? context.tr('common.sending')
                              : context.tr('common.resendCode'),
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ] else ...[
                    WTextField(
                      controller: _newPassword,
                      label: context.tr('common.newPassword'),
                      hint: context.tr('common.passwordHint'),
                      prefixIcon: Icons.lock_outline,
                      obscure: !_showPassword,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : switch (_step) {
                              _Step.email => _requestCode,
                              _Step.otp => _verifyOtp,
                              _Step.reset => _reset,
                            },
                      child: _busy
                          ? const WInlineLoader()
                          : Text(switch (_step) {
                              _Step.email => context.tr('auth.forgot.sendCode'),
                              _Step.otp => context.tr('auth.forgot.verifyCode'),
                              _Step.reset =>
                                context.tr('auth.forgot.updatePassword'),
                            }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(context.tr('auth.forgot.backToSignIn')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({required this.fields});

  final List<TextEditingController> fields;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 46,
          height: 56,
          child: TextField(
            controller: fields[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: scheme.surface,
              hintStyle: TextStyle(color: scheme.outline),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                FocusScope.of(context).nextFocus();
              }
            },
          ),
        );
      }),
    );
  }
}
