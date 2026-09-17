import 'airtime_models.dart';

/// Kontra Minit Haiti.
///
/// UI a pale ak entèfas sa a sèlman. Kle Reloadly yo pa janm nan app la:
/// tout bagay pase sou serveur a (`/api/airtime`).
abstract class AirtimeGateway {
  /// Eta sèvis la: aktive, mòd, kont Reloadly.
  Future<AirtimeServiceStatus> status();

  /// Devi: operatè nimewo a, sa benefisyè a resevwa, sa wallet la peye.
  ///
  /// Li voye MENM erè ak livrezon an (montan anba minimòm, deviz, kont vid):
  /// UI a rele l ANVAN li kreye tranzaksyon an.
  Future<AirtimeQuote> quote({
    required String phone,
    required double amount,
    String? currency,
    int? operatorId,
  });

  /// Livre yon tranzaksyon Minit Haiti.
  ///
  /// Serveur a pran montan, deviz ak nimewo a nan TRANZAKSYON AN. Yon dezyèm
  /// apèl pou menm tranzaksyon an retounen menm rechaj la.
  Future<AirtimeTopup> deliver({required String txId, int? operatorId});

  /// Mande Reloadly kote yon rechaj ki an verifikasyon ye.
  Future<AirtimeTopup> refresh(String topupId);
}
