import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class AppIds {
  AppIds._();

  static const String _namespace = '6f5dd6b4-5ed6-5d16-8d58-voupvapcash';

  static final RegExp uuid5Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static final RegExp prefixedUuid5Pattern = RegExp(
    r'^[A-Z]{2,5}_[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String agent({String? seed}) => generate(prefix: 'AG', seed: seed);
  static String admin({String? seed}) => generate(prefix: 'AD', seed: seed);
  static String owner({String? seed}) => generate(prefix: 'OW', seed: seed);
  static String client({String? seed}) => generate(prefix: 'CL', seed: seed);
  static String enterprise({String? seed}) =>
      generate(prefix: 'ENT', seed: seed);
  static String enterpriseUser({String? seed}) =>
      generate(prefix: 'EU', seed: seed);
  static String service({String? seed}) => generate(prefix: 'SVC', seed: seed);
  static String transaction({String? seed}) =>
      generate(prefix: 'TX', seed: seed);
  static String transactionRequest({String? seed}) =>
      generate(prefix: 'TXR', seed: seed);
  static String send({String? seed}) => generate(prefix: 'SEND', seed: seed);
  static String payoutRequest({String? seed}) =>
      generate(prefix: 'PO', seed: seed);
  static String topupRequest({String? seed}) =>
      generate(prefix: 'TU', seed: seed);
  static String withdrawRequest({String? seed}) =>
      generate(prefix: 'WD', seed: seed);
  static String ledger({String? seed}) => generate(prefix: 'LG', seed: seed);
  static String walletLog({String? seed}) => generate(prefix: 'WL', seed: seed);
  static String payoutLog({String? seed}) => generate(prefix: 'PL', seed: seed);
  static String history({String? seed}) => generate(prefix: 'HIS', seed: seed);
  static String transfer({String? seed}) => generate(prefix: 'TRF', seed: seed);
  static String notification({String? seed}) =>
      generate(prefix: 'NTF', seed: seed);
  static String report({String? seed}) => generate(prefix: 'RPT', seed: seed);
  static String validationLog({String? seed}) =>
      generate(prefix: 'VAL', seed: seed);

  static String userForRole(String role, {String? seed}) {
    switch (role.trim().toLowerCase()) {
      case 'agent':
        return agent(seed: seed);
      case 'admin':
      case 'administrator':
        return admin(seed: seed);
      case 'owner':
        return owner(seed: seed);
      case 'client':
      case 'customer':
      default:
        return client(seed: seed);
    }
  }

  static String generate({
    required String prefix,
    String? seed,
  }) {
    final normalizedPrefix = prefix.trim().toUpperCase();
    if (normalizedPrefix.isEmpty) {
      throw ArgumentError.value(prefix, 'prefix', 'Prefix is required.');
    }

    final name = seed?.trim().isNotEmpty == true ? seed!.trim() : _uniqueSeed();
    return '${normalizedPrefix}_${uuid5('$normalizedPrefix:$name')}';
  }

  static String uuid5(String name) {
    final namespaceBytes = utf8.encode(_namespace);
    final nameBytes = utf8.encode(name);
    final hash = sha1.convert([...namespaceBytes, ...nameBytes]).bytes;
    final bytes = Uint8List.fromList(hash.take(16).toList());

    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = bytes.map(_hex).join();
    return [
      value.substring(0, 8),
      value.substring(8, 12),
      value.substring(12, 16),
      value.substring(16, 20),
      value.substring(20),
    ].join('-');
  }

  static bool isUuid5(String value) => uuid5Pattern.hasMatch(value.trim());

  static bool isPrefixedUuid5(String value) {
    return prefixedUuid5Pattern.hasMatch(value.trim());
  }

  static String _uniqueSeed() {
    final random = Random.secure();
    final randomPart = List<int>.generate(
      8,
      (_) => random.nextInt(256),
    ).map(_hex).join();
    return '${DateTime.now().microsecondsSinceEpoch}:$randomPart';
  }

  static String _hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
}
