class Validators {
  Validators._();

  static bool isEmail(String v) => v.contains('@') && v.contains('.');
  static bool isPhone(String v) => v.replaceAll(RegExp(r'\D'), '').length >= 8;

  static String? requiredText(String? v, {String msg = 'Obligatwa'}) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }
}
