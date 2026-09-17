import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/airtime/domain/airtime_models.dart';
import 'package:mon_premye_app/pages/transactions/transaction_management_page.dart';

/// Fòm JSON yo soti dirèkteman nan `server/src/routes/airtime.routes.js`
/// (`describeOperator`, `quote`, `toJson`). Si serveur a chanje yon non chan,
/// tès sa yo kase anvan app la montre 0 HTG an silans.
void main() {
  test('devi: fòm `POST /api/airtime/quote`', () {
    final quote = AirtimeQuote.fromJson({
      'phone': '+50937123456',
      'operator': {
        'operatorId': 173,
        'name': 'Digicel Haiti',
        'denominationType': 'RANGE',
        'senderCurrency': 'USD',
        'destinationCurrency': 'HTG',
        'supportsLocalAmounts': false,
        'fxRate': 128,
        'minAmount': 1,
        'maxAmount': 70,
        'localMinAmount': 0,
        'localMaxAmount': 0,
        'fixedAmounts': <num>[],
        'localFixedAmounts': <num>[],
        'suggestedAmounts': [1, 2, 5],
      },
      'currency': 'USD',
      'amount': 5,
      'useLocalAmount': false,
      'estimatedDelivered': 640,
      'deliveredCurrency': 'HTG',
      'debit': 5,
      'mode': 'sandbox',
    });

    expect(quote.operator.operatorId, 173);
    expect(quote.operator.name, 'Digicel Haiti');
    expect(quote.operator.isFixed, isFalse);
    expect(quote.operator.maxAmount, 70);
    expect(quote.operator.suggestedAmounts, [1, 2, 5]);
    expect(quote.estimatedDelivered, 640);
    expect(quote.debit, 5);
    expect(quote.mode, 'sandbox');
    expect(quote.isConverted, isFalse, reason: 'USD -> USD: pa gen konvèsyon');
  });

  test('devi konvèti: MXN -> USD, debi nan deviz wallet la', () {
    final quote = AirtimeQuote.fromJson({
      'phone': '+50937123456',
      'operator': {'operatorId': 173, 'name': 'Digicel Haiti', 'senderCurrency': 'USD'},
      'currency': 'MXN',
      'amount': 100,
      'useLocalAmount': false,
      'sendAmount': 5.81,
      'sendCurrency': 'USD',
      'conversionRate': 0.0581626,
      'estimatedDelivered': 705.68,
      'deliveredCurrency': 'HTG',
      'debit': 100,
      'debitCurrency': 'MXN',
      'ratesUpdatedAt': 1789603201000,
      'ratesStale': false,
      'mode': 'live',
    });

    expect(quote.isConverted, isTrue);
    expect(quote.sendAmount, 5.81);
    expect(quote.debitCurrency, 'MXN');
    expect(quote.ratesUpdatedAt, 1789603201000);
  });

  test('rechaj: fòm `toJson` wout la (montan an desimal)', () {
    final topup = AirtimeTopup.fromJson({
      'topupId': 'AIR_x',
      'status': 'failed',
      'amount': 5,
      'currency': 'USD',
      'operatorName': 'Natcom Haiti',
      'phone': '+50933123456',
      'estimatedDelivered': 640,
      'delivered': 0,
      'deliveredCurrency': 'HTG',
      'gatewayId': '',
      'refunded': true,
      'failureReason': 'transaction_cannot_be_processed_at_the_moment',
    });

    expect(topup.status, AirtimeTopupStatus.failed);
    expect(topup.isFinal, isTrue);
    expect(topup.refunded, isTrue);
    expect(topup.gatewayId, isEmpty);
  });

  test('estati enkoni = an verifikasyon, jamè "reyisi"', () {
    expect(airtimeStatusFrom('completed'), AirtimeTopupStatus.completed);
    expect(airtimeStatusFrom('failed'), AirtimeTopupStatus.failed);
    expect(airtimeStatusFrom('processing'), AirtimeTopupStatus.processing);
    expect(airtimeStatusFrom('something_new'), AirtimeTopupStatus.processing);
  });

  test('eta sèvis: dezaktive an pwodiksyon san kle', () {
    final status = AirtimeServiceStatus.fromJson({
      'mode': 'fake',
      'enabled': false,
      'reachesReloadly': false,
      'warning': 'Minit Haiti poko aktive',
    });

    expect(status.canSend, isFalse);
    expect(status.warning, contains('poko aktive'));
  });

  test('chak sèvis livre pa bon pasrèl la', () {
    expect(DeliveryChannel.forService('MonCash'), DeliveryChannel.bazik);
    expect(DeliveryChannel.forService('NatCash'), DeliveryChannel.bazik);
    expect(DeliveryChannel.forService('Minit Haiti'), DeliveryChannel.reloadly);
    // Anvan: dyalòg Bazik la te tonbe sou MonCash pou sèvis sa yo.
    expect(DeliveryChannel.forService('Western Union'), DeliveryChannel.manual);
    expect(DeliveryChannel.forService('CAM Transf'), DeliveryChannel.manual);
  });
}
