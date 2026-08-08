class EmailValidator {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates an email string.
  /// 
  /// Rejects:
  /// - Empty email
  /// - Missing @
  /// - Missing username
  /// - Missing domain
  /// - Missing TLD
  /// - Multiple @ symbols
  /// - Leading/trailing spaces (should be trimmed before passing, but handled here just in case)
  static bool isValid(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Normalizes an email for storage and comparison
  static String normalize(String email) {
    return email.trim().toLowerCase();
  }
}
