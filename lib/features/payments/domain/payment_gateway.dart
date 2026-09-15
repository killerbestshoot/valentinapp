import 'payment_models.dart';

/// Kontra pasrèl peman an.
///
/// UI a pale ak entèfas sa a sèlman. Jodi a se Bazik ki dèyè l, atravè yon
/// serveur; demen si nou chanje founisè, se yon sèl klas ki chanje.
///
/// Enpòtan: okenn aplikasyon pa dwe rele Bazik dirèkteman depi telefòn nan —
/// `secretKey` la pa ka viv nan yon APK. Tout bagay pase sou serveur.
abstract class PaymentGateway {
  /// Konbyen sa ap koute, san anyen pa deplase.
  Future<TransferQuote> quote({
    required double amount,
    required PaymentNetwork network,
    String? currency,
  });

  /// Voye lajan bay yon benefisyè.
  ///
  /// [idempotencySeed] enpòtan: menm seed = menm transfè, donk yon doub-klik
  /// pa voye lajan an de fwa.
  Future<Transfer> send({
    required double amount,
    required PaymentNetwork network,
    required String phone,
    String receiverName,
    String note,
    String txId,
    String kind,
    String? currency,
    String? idempotencySeed,
  });

  /// Mande pasrèl la kote yon transfè ye (si webhook la pèdi).
  Future<Transfer> refresh(String transferId);

  /// Sld wallet ajan ki konekte a.
  Future<WalletBalance> wallet();

  /// Eta pasrèl la: mòd (fake/sandbox/live) ak pwovizyon float Bazik la.
  ///
  /// UI a sèvi ak sa pou avèti ajan an AVAN li eseye voye: si nou an
  /// similasyon, oswa si float la vid, transfè a p ap janm rive sou Bazik.
  Future<GatewayStatus> status();
}
