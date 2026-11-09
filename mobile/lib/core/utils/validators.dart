/// Input validation helpers for forms, registration, and onboarding.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  static final RegExp _phoneRegExp = RegExp(
    r'^[+0-9]{10,14}$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final clean = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!_phoneRegExp.hasMatch(clean)) {
      return 'Please enter a valid 10-digit phone number.';
    }
    return null;
  }
}

