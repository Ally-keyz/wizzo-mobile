import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_widgets.dart';
import '../providers/auth_provider.dart';

/// Step-by-step seller sign-up (2 fields per step) plus email verification,
/// mirroring the web `/sign-up/seller` wizard.
class SellerSignUpScreen extends ConsumerStatefulWidget {
  const SellerSignUpScreen({super.key, this.individual = false});

  /// Opened from the "individual trader" choice, skipping the storefront
  /// details. The account type can still be switched on the first step.
  final bool individual;

  @override
  ConsumerState<SellerSignUpScreen> createState() => _SellerSignUpScreenState();
}

class _SellerSignUpScreenState extends ConsumerState<SellerSignUpScreen> {
  static const _stepCount = 6;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _storeName = TextEditingController();
  final _aboutStore = TextEditingController();
  final _country = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _code = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _showPassword = false;
  bool _individual = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _individual = widget.individual;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _storeName.dispose();
    _aboutStore.dispose();
    _country.dispose();
    _district.dispose();
    _city.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        // Validate the two fields independently. Chaining
        // `Validator.fullName(...) ?? Validator.email(...)!` crashed with a
        // null-assertion error whenever BOTH values were valid (both helpers
        // return null), which made the Continue button do nothing.
        final nameError = Validators.fullName(_fullName.text);
        if (nameError != null) return localizeError(context, nameError);
        final emailError = Validators.email(_email.text);
        if (emailError != null) return localizeError(context, emailError);
        return null;
      case 1:
        final pass = Validators.password(_password.text);
        if (pass != null) return localizeError(context, pass);
        if (_password.text != _confirm.text) {
          return context.tr('common.errors.passwordsDoNotMatch');
        }
        return null;
      case 2:
        final storeName = _storeName.text.trim();
        if (storeName.isEmpty) {
          return context.tr(
            'common.errors.isRequired',
            namedArgs: {'label': context.tr('common.storeName')},
          );
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _createStore() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerSeller(
            fullName: _fullName.text,
            email: _email.text,
            password: _password.text,
            sellerType: _individual ? 'individual' : 'business',
            storeName: _individual ? _fullName.text.trim() : _storeName.text,
            aboutStore: _individual ? null : _aboutStore.text,
            country: _individual ? null : _country.text,
            district: _individual ? null : _district.text,
            city: _individual ? null : _city.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 5;
      });
      _startResendTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = localizeException(context, e);
          _busy = false;
        });
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendIn -= 1;
        if (_resendIn <= 0) {
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendIn > 0) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendEmailOtp(_email.text);
      if (!mounted) return;
      setState(() => _busy = false);
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('common.errors.codeResent'))),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = localizeException(context, e);
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = context.tr('common.errors.enterSixDigitCode'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmailOtp(_email.text, code);
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = localizeException(context, e);
          _busy = false;
        });
      }
    }
  }

  void _next() {
    final error = _validateCurrentStep();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step == 1 && _individual) {
      // Individual traders have no storefront details, so account creation
      // starts right after the password step.
      _createStore();
      return;
    }
    setState(() {
      _error = null;
      _step += 1;
    });
  }

  void _back() {
    if (_step == 5 && _individual) {
      setState(() {
        _error = null;
        _step = 1;
      });
      return;
    }
    if (_step > 0) {
      setState(() {
        _error = null;
        _step -= 1;
      });
    } else {
      context.go('/role-choice');
    }
  }

  String get _buttonLabel {
    if (_step == 1 && _individual) {
      return context.tr('auth.seller.createAccount');
    }
    return switch (_step) {
      4 => context.tr('auth.seller.createStore'),
      5 => context.tr('auth.seller.verifyEmail'),
      _ => context.tr('common.continueLabel'),
    };
  }

  Widget _typeCard(
    ColorScheme scheme,
    bool individual,
    String label,
    IconData icon,
  ) {
    final selected = _individual == individual;
    return InkWell(
      onTap: () => setState(() {
        _individual = individual;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _step == 5;
    final displayStepCount = _individual ? 3 : _stepCount;
    final displayStepIndex = _individual && _step > 1 ? 2 : _step;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: WAppMark(size: 40)),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('auth.seller.title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _step == 5
                            ? context.tr('auth.seller.verifySubtitle')
                            : _individual
                            ? context.tr('auth.seller.individualSubtitle')
                            : context.tr('auth.seller.subtitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_step > 0 && !isLast) ...[
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_step == 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _typeCard(
                                scheme,
                                true,
                                context.tr('auth.seller.individual'),
                                Icons.person_outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _typeCard(
                                scheme,
                                false,
                                context.tr('auth.seller.business'),
                                Icons.store_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            _individual
                                ? 'auth.seller.individualHint'
                                : 'auth.seller.businessHint',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                      ] else if (_step == 1) ...[
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
                      ] else if (_step == 2) ...[
                        WTextField(
                          controller: _storeName,
                          label: context.tr('common.storeName'),
                          hint: context.tr('common.storeNameHint'),
                          prefixIcon: Icons.store_outlined,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        WTextField(
                          controller: _aboutStore,
                          label: context.tr('common.aboutStore'),
                          hint: context.tr('common.aboutStoreHint'),
                          prefixIcon: Icons.notes_outlined,
                          textInputAction: TextInputAction.done,
                        ),
                      ] else if (_step == 3) ...[
                        WTextField(
                          controller: _country,
                          label: context.tr('common.country'),
                          hint: context.tr('common.countryHint'),
                          prefixIcon: Icons.public,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        WTextField(
                          controller: _district,
                          label: context.tr('common.district'),
                          hint: context.tr('common.districtHint'),
                          prefixIcon: Icons.place_outlined,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                        ),
                      ] else if (_step == 4) ...[
                        WTextField(
                          controller: _city,
                          label: context.tr('common.city'),
                          hint: context.tr('common.cityHint'),
                          prefixIcon: Icons.location_city,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                        ),
                      ] else ...[
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              size: 28,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            'auth.seller.weSentCode',
                            namedArgs: {'email': _email.text},
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        WTextField(
                          controller: _code,
                          label: context.tr('common.verificationCode'),
                          hint: context.tr('common.verificationCodeHint'),
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _busy || _resendIn > 0
                                ? null
                                : _resendCode,
                            child: Text(
                              _resendIn > 0
                                  ? context.tr(
                                      'common.resendCodeIn',
                                      namedArgs: {'seconds': '$_resendIn'},
                                    )
                                  : context.tr('common.resendCode'),
                              style: TextStyle(color: scheme.primary),
                            ),
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
                              : _step == 4
                              ? _createStore
                              : _step == 5
                              ? _verifyCode
                              : _next,
                          child: _busy
                              ? const WInlineLoader()
                              : Text(_buttonLabel),
                        ),
                      ),
                      const SizedBox(height: 20),
                      WStepBars(
                        count: displayStepCount,
                        index: displayStepIndex,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              context.tr('common.alreadyHaveAccount'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
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
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
