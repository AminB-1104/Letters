class Validators {
  Validators._();

  static final RegExp _emailRegex =
      RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'Value'}) {
    if (value == null || value.length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }
}
