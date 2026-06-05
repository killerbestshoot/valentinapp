import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/services/shared/app_ids.dart';

void main() {
  test('generates deterministic UUID v5 values', () {
    final first = AppIds.uuid5('agent:test@example.com');
    final second = AppIds.uuid5('agent:test@example.com');

    expect(first, second);
    expect(AppIds.isUuid5(first), isTrue);
  });

  test('prefixes IDs by operation level', () {
    final agentId = AppIds.agent(seed: 'agent-1');
    final adminId = AppIds.admin(seed: 'admin-1');
    final txId = AppIds.transaction(seed: 'tx-1');
    final payoutId = AppIds.payoutRequest(seed: 'payout-1');

    expect(agentId, startsWith('AG_'));
    expect(adminId, startsWith('AD_'));
    expect(txId, startsWith('TX_'));
    expect(payoutId, startsWith('PO_'));
    expect(AppIds.isPrefixedUuid5(agentId), isTrue);
    expect(AppIds.isPrefixedUuid5(adminId), isTrue);
    expect(AppIds.isPrefixedUuid5(txId), isTrue);
    expect(AppIds.isPrefixedUuid5(payoutId), isTrue);
  });
}
