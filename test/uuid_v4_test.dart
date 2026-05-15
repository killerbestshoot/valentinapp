import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/services/uuid_v4.dart';

void main() {
  test('generates valid uuid v4 values', () {
    final ids = List.generate(
      25,
      (index) => UuidV4.generate(random: Random(index)),
    );

    expect(ids.toSet(), hasLength(ids.length));

    for (final id in ids) {
      expect(UuidV4.isValid(id), isTrue);
      expect(id[14], '4');
      expect(['8', '9', 'a', 'b'], contains(id[19]));
    }
  });
}
