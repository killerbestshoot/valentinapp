import 'package:flutter/material.dart';

import '../../domain/payment_models.dart';

/// Tradiksyon erè pasrèl yo an mesaj ki itil pou moun k ap sèvi ak app la.
///
/// Poukisa yon sèl kote: `insufficient_balance` ka soti nan 3 kote diferan
/// (sòld ajan, float Bazik, refi Bazik). Si chak ekran ekri pwòp mesaj li,
/// ajan an ap li yon bagay diferan chak fwa pou menm pwoblèm nan.
///
/// Chak erè bay 3 bagay:
///   - `title`  : sa ki pase, an kat mo
///   - `detail` : poukisa
///   - `action` : sa pou fè KOUNYE A (se sa ki manke pi souvan)
class PaymentErrorInfo {
  const PaymentErrorInfo({
    required this.title,
    required this.detail,
    required this.action,
    required this.severity,
  });

  final String title;
  final String detail;
  final String action;
  final PaymentErrorSeverity severity;

  /// Erè ajan an ka regle li menm vs erè ki mande yon administratè.
  bool get needsAdmin => severity == PaymentErrorSeverity.blocking;

  static PaymentErrorInfo from(PaymentException error) {
    switch (error.code) {
      // --- Sòld ---
      case 'insufficient_funds':
        return const PaymentErrorInfo(
          title: 'Sòld ou pa ase',
          detail: 'Wallet ou a pa gen ase kòb pou montan sa a plis frè yo.',
          action: 'Mande yon rechaj bay administratè a, oswa diminye montan an.',
          severity: PaymentErrorSeverity.userFixable,
        );

      case 'gateway_underfunded':
        return PaymentErrorInfo(
          title: 'Kont Bazik la san pwovizyon',
          detail: error.message,
          action:
              'Se administratè a ki dwe chaje kont Bazik la. Okenn transfè '
              'p ap ka pati anvan sa.',
          severity: PaymentErrorSeverity.blocking,
        );

      case 'insufficient_balance':
        return const PaymentErrorInfo(
          title: 'Bazik refize: pwovizyon an pa ase',
          detail:
              'Bazik refize transfè a paske kont lan pa gen ase kòb '
              '(montan an plis 5% frè).',
          action: 'Wallet ou ranbouse. Avèti administratè a pou l chaje kont Bazik la.',
          severity: PaymentErrorSeverity.blocking,
        );

      // --- Montan ---
      case 'amount_too_low':
        return PaymentErrorInfo(
          title: 'Montan an twò piti',
          detail: error.message,
          action: 'Ogmante montan an jiskaske li rive nan minimòm nan.',
          severity: PaymentErrorSeverity.userFixable,
        );

      case 'amount_too_high':
        return PaymentErrorInfo(
          title: 'Montan an twò gwo',
          detail: error.message,
          action: 'Separe l an plizyè transfè, oswa diminye montan an.',
          severity: PaymentErrorSeverity.userFixable,
        );

      case 'invalid_amount':
        return const PaymentErrorInfo(
          title: 'Montan an pa valid',
          detail: 'Montan an dwe yon nonm pi gran pase 0.',
          action: 'Korije montan an.',
          severity: PaymentErrorSeverity.userFixable,
        );

      // --- Benefisyè ---
      case 'invalid_wallet':
        return const PaymentErrorInfo(
          title: 'Nimewo a pa valid',
          detail: 'Nou tann yon nimewo Ayiti ak 8 chif.',
          action: 'Verifye nimewo benefisyè a.',
          severity: PaymentErrorSeverity.userFixable,
        );

      case 'missing_receiver_name':
        return const PaymentErrorInfo(
          title: 'Non benefisyè a manke',
          detail: 'NatCash mande non ak siyati benefisyè a, MonCash pa mande l.',
          action: 'Antre non konplè a, oswa pase sou MonCash.',
          severity: PaymentErrorSeverity.userFixable,
        );

      // --- Konfigirasyon / kont ---
      case 'cash_in_unavailable':
      case 'endpoint_not_authorized':
        return const PaymentErrorInfo(
          title: 'Kont Bazik la pa gen dwa sa a',
          detail:
              'Kont lan se yon kont tip `transfer`: li ka voye lajan men li pa '
              'ka ankese.',
          action: 'Fòk yo louvri yon kont `online` sou Bazik pou rechaj mache.',
          severity: PaymentErrorSeverity.blocking,
        );

      case 'unauthorized':
        return const PaymentErrorInfo(
          title: 'Kle Bazik yo pa bon',
          detail: 'Bazik refize idantifye serveur a.',
          action: 'Administratè a dwe verifye kle API yo.',
          severity: PaymentErrorSeverity.blocking,
        );

      case 'missing_rate':
        return const PaymentErrorInfo(
          title: 'To echanj lan manke',
          detail: 'Nou pa ka konvèti deviz la an HTG san yon to.',
          action: 'Administratè a dwe mete to a nan paramèt yo.',
          severity: PaymentErrorSeverity.blocking,
        );

      // --- Rezo ---
      case 'rate_limited':
        return const PaymentErrorInfo(
          title: 'Twòp demand',
          detail: 'Nou depase limit Bazik la (100 demand pa minit).',
          action: 'Tann yon minit epi eseye ankò.',
          severity: PaymentErrorSeverity.retryable,
        );

      case 'network_error':
      case 'bad_response':
        return const PaymentErrorInfo(
          title: 'Koneksyon an koupe',
          detail: 'Nou pa rive jwenn serveur a.',
          action: 'Verifye koneksyon an epi eseye ankò.',
          severity: PaymentErrorSeverity.retryable,
        );

      case 'unauthenticated':
        return const PaymentErrorInfo(
          title: 'Ou pa konekte',
          detail: 'Sesyon an fini oswa li pa valid.',
          action: 'Konekte ankò.',
          severity: PaymentErrorSeverity.blocking,
        );

      default:
        return PaymentErrorInfo(
          title: 'Transfè a pa pase',
          detail: error.message,
          action: 'Si pwoblèm nan kontinye, avèti administratè a (kòd: ${error.code}).',
          severity: PaymentErrorSeverity.retryable,
        );
    }
  }
}

enum PaymentErrorSeverity {
  /// Moun nan ka korije sa li menm (montan, nimewo...).
  userFixable,

  /// Eseye ankò ka mache (rezo, limit).
  retryable,

  /// Fòk yon administratè entèvni: eseye ankò p ap chanje anyen.
  blocking,
}

/// Afichaj yon erè pasrèl, ak sa pou fè.
class PaymentErrorView extends StatelessWidget {
  const PaymentErrorView({super.key, required this.error, this.onRetry});

  final PaymentException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final info = PaymentErrorInfo.from(error);
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground, icon) = switch (info.severity) {
      PaymentErrorSeverity.userFixable => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.edit_outlined,
        ),
      PaymentErrorSeverity.retryable => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.refresh,
        ),
      PaymentErrorSeverity.blocking => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.block_outlined,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.title,
                  style: TextStyle(fontWeight: FontWeight.w900, color: foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(info.detail, style: TextStyle(color: foreground)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_forward, size: 16, color: foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.action,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null && info.severity == PaymentErrorSeverity.retryable) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Eseye ankò'),
              ),
            ),
          ],
          // Kòd la toujou vizib: se sa ki pèmèt yon ajan di administratè a
          // egzakteman ki erè li wè.
          const SizedBox(height: 6),
          Text(
            'kòd: ${error.code}',
            style: TextStyle(
              color: foreground.withValues(alpha: 0.7),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
