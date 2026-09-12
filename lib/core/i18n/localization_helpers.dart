import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../network/api_exception.dart';

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

/// Maps a thrown [ApiException] or a stable upload/chat error message to its
/// localized equivalent. Unknown messages pass through unchanged.
String localizeException(BuildContext context, Object error) {
  final message = error.toString();
  if (error is ApiException) {
    switch (error.code) {
      case 'unauthorized':
        return context.tr('common.sessionExpired');
      case 'timeout':
        return context.tr('common.timeoutError');
      case 'network':
        return context.tr('common.networkError');
      case 'cancelled':
        return context.tr('auth.googleCancelled');
      case 'google-config':
        return context.tr('auth.googleNoToken');
      case 'upload':
        return context.tr('common.uploadPrepareFailed');
      case 'auth':
        if (message.contains('Sign-in failed')) {
          return context.tr('auth.loginFailed');
        }
        if (message.contains('session could not be upgraded')) {
          return context.tr('auth.sessionUpgradeFailed');
        }
        if (message.contains('invalid response')) {
          return context.tr('auth.invalidServerResponse');
        }
        break;
    }
    if (message.contains('Something went wrong')) {
      return context.tr(
        'common.genericError',
        namedArgs: {'status': '${error.status}'},
      );
    }
    return message;
  }
  if (message.startsWith('Image upload failed (')) {
    return context.tr(
      'common.uploadImageFailed',
      namedArgs: {'status': _between(message, '(', ')')},
    );
  }
  if (message.startsWith('Video upload failed (')) {
    return context.tr(
      'common.uploadVideoFailed',
      namedArgs: {'status': _between(message, '(', ')')},
    );
  }
  if (message.startsWith('Could not prepare')) {
    return context.tr('common.uploadPrepareFailed');
  }
  if (message == 'Could not get an upload signature') {
    return context.tr('chat.uploadSignatureFailed');
  }
  if (message.startsWith('Could not read the selected file')) {
    return context.tr(
      'chat.uploadReadFailed',
      namedArgs: {'error': _after(message, ':')},
    );
  }
  if (message.startsWith('Upload failed: ')) {
    return context.tr(
      'chat.uploadFailed',
      namedArgs: {'error': _after(message, ':')},
    );
  }
  if (message.startsWith('Upload failed (')) {
    return context.tr(
      'chat.uploadFailedStatus',
      namedArgs: {'status': _between(message, '(', ')')},
    );
  }
  return message;
}

String _between(String text, String open, String close) {
  final start = text.indexOf(open);
  final end = text.indexOf(close, start + 1);
  if (start < 0 || end < 0) return text;
  return text.substring(start + 1, end);
}

String _after(String text, String separator) {
  final index = text.indexOf(separator);
  if (index < 0) return '';
  return text.substring(index + separator.length).trim();
}