import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

const _validatorKeys = <String, String>{
  'Email is required': 'common.errors.emailRequired',
  'Enter a valid email address': 'common.errors.invalidEmail',
  'Password is required': 'common.errors.passwordRequired',
  'Password must be at least 8 characters': 'common.errors.passwordMin',
  'Full name is required': 'common.errors.fullNameRequired',
  'Full name must be at least 3 characters': 'common.errors.fullNameMin',
  'Enter a valid phone number': 'common.errors.invalidPhone',
};

/// Maps a raw [Validators] error message to its localized equivalent.
///
/// Unknown (e.g. server) messages pass through unchanged.
String localizeError(BuildContext context, String raw) {
  final key = _validatorKeys[raw];
  return key == null ? raw : context.tr(key);
}