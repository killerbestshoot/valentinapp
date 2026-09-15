import '../domain/payment_gateway.dart';
import '../domain/payment_models.dart';

/// Pasrèl an memwa: tès widget ak mòd `MOCK_FIREBASE=true`.
///
/// Li kopye menm règ ak vre pasrèl la (frè 5%, minimòm chak rezo, sld ki
/// bese), konsa UI a wè menm konpòtman an san okenn serveur.
class FakePaymentGateway implements PaymentGateway {
  FakePaymentGateway({
    this.rateToHtg = 132,
    double balance = 500,
    this.feePercent = 5,
    this.failingPhones = const {'37000000'},
  }) : _balance = balance;

  final double rateToHtg;
  final double feePercent;
  final Set<String> failingPhones;

  double _balance;
  int _counter = 0;

  final List<Transfer> sent = [];

  double get balance => _balance;

  String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Future<TransferQuote> quote({
    required double amount,
    required PaymentNetwork network,
    String? currency,
  }) async {
    final amountHtg = amount * rateToHtg;
    final feeHtg = amountHtg * feePercent / 100;

    return TransferQuote(
      network: network,
      currency: currency ?? 'USD',
      amountHtg: amountHtg,
      feeHtg: feeHtg,
      totalHtg: amountHtg + feeHtg,
      feePercent: feePercent,
      debit: (amountHtg + feeHtg) / rateToHtg,
      rateToHtg: rateToHtg,
    );
  }

  @override
  Future<Transfer> send({
    required double amount,
    required PaymentNetwork network,
    required String phone,
    String receiverName = '',
    String note = '',
    String txId = '',
    String kind = 'payout',
    String? currency,
    String? idempotencySeed,
  }) async {
    final amountHtg = amount * rateToHtg;

    if (network.requiresReceiverName && receiverName.trim().isEmpty) {
      throw const PaymentException(
        'missing_receiver_name',
        'NatCash mande non konplè benefisyè a.',
      );
    }

    if (amountHtg < network.minimumHtg) {
      throw PaymentException(
        'amount_too_low',
        'Minimòm pou ${network.label} se ${network.minimumHtg.toStringAsFixed(0)} HTG.',
      );
    }

    if (amountHtg > 75000) {
      throw const PaymentException(
        'amount_too_high',
        'Maksimòm se 75000 HTG pa tranzaksyon.',
      );
    }

    final feeHtg = amountHtg * feePercent / 100;
    final debit = (amountHtg + feeHtg) / rateToHtg;

    if (debit > _balance) {
      throw const PaymentException('insufficient_funds', 'Sld wallet la pa ase.');
    }

    final failed = failingPhones.contains(
      _digits(phone).length > 8 ? _digits(phone).substring(_digits(phone).length - 8) : _digits(phone),
    );

    if (!failed) _balance -= debit;

    _counter += 1;

    final transfer = Transfer(
      transferId: 'TRF_fake_$_counter',
      reference: 'TRF_fake_$_counter',
      status: failed ? TransferStatus.failed : TransferStatus.processing,
      network: network,
      amountHtg: amountHtg,
      feeHtg: feeHtg,
      debit: debit,
      currency: currency ?? 'USD',
      phone: phone,
      receiverName: receiverName,
      failureReason: failed ? 'Nimewo a pa ka resevwa lajan.' : '',
      refunded: failed,
    );

    sent.add(transfer);
    return transfer;
  }

  @override
  Future<Transfer> refresh(String transferId) async {
    final transfer = sent.firstWhere(
      (item) => item.transferId == transferId,
      orElse: () => throw const PaymentException('transfer_not_found', 'Transfè a pa egziste.'),
    );

    if (transfer.status != TransferStatus.processing) return transfer;

    final completed = Transfer(
      transferId: transfer.transferId,
      reference: transfer.reference,
      status: TransferStatus.completed,
      network: transfer.network,
      amountHtg: transfer.amountHtg,
      feeHtg: transfer.feeHtg,
      debit: transfer.debit,
      currency: transfer.currency,
      phone: transfer.phone,
      receiverName: transfer.receiverName,
    );

    sent[sent.indexOf(transfer)] = completed;
    return completed;
  }

  @override
  Future<GatewayStatus> status() async {
    // Similatè a di laverite sou tèt li: anyen pa rive sou Bazik.
    return const GatewayStatus(
      mode: 'fake',
      reachesBazik: false,
      warning: 'Mòd similasyon: okenn transfè p ap parèt sou dashboard Bazik la.',
    );
  }

  @override
  Future<WalletBalance> wallet() async {
    return WalletBalance(balance: _balance, currency: 'USD');
  }
}
