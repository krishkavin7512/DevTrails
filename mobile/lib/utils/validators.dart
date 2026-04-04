class Validators {
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(v.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? required(String? v, [String field = 'Field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? objectId(String? v) {
    if (v == null || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(v)) {
      return 'Invalid ID format';
    }
    return null;
  }

  static String? pincode(String? v) {
    if (v == null || !RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }
}
