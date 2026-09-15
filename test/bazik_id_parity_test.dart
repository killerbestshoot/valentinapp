import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/services/shared/app_ids.dart';

/// PARITE DART <-> NODE.
///
/// Menm fiksti sa yo kopye nan `bazik/test/ids_money.test.js`. Si yon moun
/// chanje algorithm ID a yon bò san lòt la, youn nan de tès yo kase.
///
/// Poukisa sa enpòtan: ID sa yo sèvi kòm `referenceId` sou Bazik, donk kòm kle
/// idempotans. Si Dart ak Node pa dakò, yon menm demand ta ka pati de fwa.
void main() {
  group('ID Dart yo dwe idantik ak ID Node yo', () {
    const fixtures = <List<String>>[
      ['TU', 'seed-test', 'TU_02a0ee17-3687-5619-8457-cdb9fdc3f84f'],
      ['TU', 'TU:abc', 'TU_4064ed69-dcd1-5a0b-b962-804f1e1831b5'],
      [
        'TU',
        'enterprise-1:uid-9:2026-01-01',
        'TU_99f17563-0c18-5949-8883-a698eb806bdc',
      ],
      ['TRF', 'seed-test', 'TRF_382288a7-4eec-557d-8ab5-3bd3e5cd2c49'],
      ['LG', 'seed-test', 'LG_6c08793b-ceae-5d1d-88f5-b626f57a7199'],
    ];

    for (final fixture in fixtures) {
      final prefix = fixture[0];
      final seed = fixture[1];
      final expected = fixture[2];

      test('$prefix:$seed', () {
        expect(AppIds.generate(prefix: prefix, seed: seed), expected);
      });
    }
  });

  test('menm seed bay menm ID', () {
    expect(
      AppIds.transfer(seed: 'abc'),
      AppIds.transfer(seed: 'abc'),
    );
    expect(
      AppIds.transfer(seed: 'abc'),
      isNot(AppIds.transfer(seed: 'abd')),
    );
  });
}
