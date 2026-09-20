import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/format/haiti_phone.dart';

void main() {
  group('HaitiPhone', () {
    test('kenbe 8 chif yo', () {
      expect(HaitiPhone.localPart('37123456'), '37123456');
      expect(HaitiPhone.localPart('3712 3456'), '37123456');
      expect(HaitiPhone.localPart('3712-3456'), '37123456');
    });

    test('retire prefiks la si moun nan kole yon nimewo konplè', () {
      expect(HaitiPhone.localPart('+509 3712 3456'), '37123456');
      expect(HaitiPhone.localPart('50937123456'), '37123456');
      expect(HaitiPhone.localPart('0050937123456'), '37123456');
    });

    test('yon nimewo ki KÒMANSE ak 509 pa pèdi chif', () {
      // 5093 4567 se yon vre nimewo lokal: 8 chif, nou pa touche l.
      expect(HaitiPhone.localPart('50934567'), '50934567');
    });

    test('koupe sa ki depase', () {
      expect(HaitiPhone.localPart('371234567890'), '37123456');
    });

    test('validasyon sou longè a', () {
      expect(HaitiPhone.isValid('37123456'), isTrue);
      expect(HaitiPhone.isValid('+509 3712 3456'), isTrue);
      expect(HaitiPhone.isValid('3712345'), isFalse, reason: '7 chif');
      expect(HaitiPhone.isValid(''), isFalse);
    });

    test('fòm entènasyonal pou pasrèl yo', () {
      expect(HaitiPhone.international('3712 3456'), '+50937123456');
      expect(HaitiPhone.international('+509 3712 3456'), '+50937123456');
    });

    test('fòm lizib pou ekran ak resi', () {
      expect(HaitiPhone.pretty('37123456'), '+509 3712 3456');
    });
  });
}
