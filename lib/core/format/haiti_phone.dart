import 'package:flutter/services.dart';

/// Nimewo telefòn Ayiti.
///
/// Tout benefisyè yo an Ayiti: MonCash, NatCash ak Minit Haiti pa livre lòt
/// kote. Donk prefiks la se toujou +509, e li pa yon bagay pou ajan an tape —
/// se yon bagay pou app la konnen. Ajan an tape 8 chif yo sèlman.
class HaitiPhone {
  const HaitiPhone._();

  static const code = '509';
  static const localDigits = 8;

  /// Kenbe chif yo sèlman, epi retire prefiks la si moun nan kole yon nimewo
  /// konplè (`+509 3712 3456`, `0050937123456`).
  static String localPart(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00$code')) {
      digits = digits.substring(2 + code.length);
    } else if (digits.length > localDigits && digits.startsWith(code)) {
      digits = digits.substring(code.length);
    }

    return digits.length > localDigits
        ? digits.substring(0, localDigits)
        : digits;
  }

  static bool isValid(String input) =>
      localPart(input).length == localDigits;

  /// Fòm nou voye bay pasrèl yo: `+50937123456`.
  static String international(String input) => '+$code${localPart(input)}';

  /// Sa nou montre: `+509 3712 3456`.
  static String pretty(String input) {
    final local = localPart(input);
    if (local.length != localDigits) return '+$code $local';
    return '+$code ${local.substring(0, 4)} ${local.substring(4)}';
  }
}

/// Kenbe chan an sou 8 chif, menm lè moun nan kole yon nimewo konplè.
class HaitiPhoneInputFormatter extends TextInputFormatter {
  const HaitiPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final local = HaitiPhone.localPart(newValue.text);

    if (local == newValue.text) return newValue;

    return TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }
}
