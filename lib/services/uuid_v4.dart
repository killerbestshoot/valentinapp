import 'dart:math';

class UuidV4 {
  UuidV4._();

  static final RegExp pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();

    return [
      value.substring(0, 8),
      value.substring(8, 12),
      value.substring(12, 16),
      value.substring(16, 20),
      value.substring(20),
    ].join('-');
  }

  static bool isValid(String value) => pattern.hasMatch(value.trim());
}
