import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';

void main() {
  test('sèlman sijè ki konsène yo, ak plizyè siyal = yon sèl rechajman', () async {
    var calls = 0;
    final sub = Realtime.instance.listen(
      const {'transactions'},
      () => calls++,
      debounce: const Duration(milliseconds: 50),
    );

    Realtime.instance.debugReceive('change', '{"topics":["wallets"]}');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 0, reason: 'wallets pa konsène ekran sa a');

    Realtime.instance.debugReceive('change', '{"topics":["transactions"]}');
    Realtime.instance.debugReceive('change', '{"topics":["transactions","transfers"]}');
    Realtime.instance.debugReceive('change', '{"topics":["transactions"]}');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1, reason: '3 siyal pre youn lòt = 1 rechajman');

    Realtime.instance.debugReceive('change', 'pa json');
    Realtime.instance.debugReceive('hello', '{}');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);

    await sub.cancel();
  });
}
