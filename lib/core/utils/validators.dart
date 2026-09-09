/// Lightweight validation helpers, matching the web forms' rules.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');
  static final RegExp _phone = RegExp(r'^\+?[0-9]{9,15}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 3) return 'Full name must be at least 3 characters';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_phone.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? optional(String? value) => null;
}