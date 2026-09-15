import 'package:flutter/material.dart';

import '../../data/payment_gateway_provider.dart';
import '../../domain/payment_gateway.dart';
import '../../domain/payment_models.dart';

/// Kat eta pasrèl Bazik la, pou dashboard admin nan.
///
/// Rezon li egziste: lè yon admin di "mwen pa wè anyen sou dashboard Bazik la",
/// repons lan prèske toujou youn nan de bagay sa yo — e ni youn ni lòt pa t
/// vizib okenn kote nan app la:
///
///   1. app la an mòd similasyon (okenn apèl pa kite machin nan);
///   2. float Bazik la vid (Bazik refize chak transfè anvan li kreye l).
class GatewayStatusCard extends StatefulWidget {
  const GatewayStatusCard({super.key, this.gateway});

  final PaymentGateway? gateway;

  @override
  State<GatewayStatusCard> createState() => _GatewayStatusCardState();
}

class _GatewayStatusCardState extends State<GatewayStatusCard> {
  late Future<GatewayStatus> _future;

  PaymentGateway get _gateway => widget.gateway ?? PaymentGatewayProvider.instance;

  @override
  void initState() {
    super.initState();
    _future = _gateway.status();
  }

  void _reload() {
    // Fòm blòk obligatwa: `setState(() => _future = ...)` retounen Future a,
    // epi Flutter leve yon erè paske li kwè nou fè travay async ladan.
    setState(() {
      _future = _gateway.status();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GatewayStatus>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Shell(
            icon: Icons.sync,
            color: Color(0xFF64748B),
            title: 'Pasrèl Bazik',
            detail: 'N ap tcheke eta a...',
          );
        }

        if (snap.hasError) {
          final error = snap.error;
          return _Shell(
            icon: Icons.cloud_off_outlined,
            color: const Color(0xFFB91C1C),
            title: 'Pasrèl Bazik pa reponn',
            detail: error is PaymentException
                ? error.message
                : 'Serveur peman an pa jwenn.',
            onRetry: _reload,
          );
        }

        final status = snap.data!;

        if (!status.reachesBazik) {
          return _Shell(
            icon: Icons.science_outlined,
            color: const Color(0xFFB45309),
            title: 'Mòd similasyon',
            detail:
                'Transfè yo rete lokal. Anyen p ap parèt sou dashboard Bazik la '
                'toutotan kle yo pa konfigire.',
            onRetry: _reload,
          );
        }

        if (!status.gatewayFunded) {
          return _Shell(
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFFB91C1C),
            title: 'Kont Bazik la vid',
            detail:
                'Float: ${status.available.toStringAsFixed(2)} ${status.currency}. '
                'Bazik ap refize chak transfè ak `insufficient_balance`, e li p ap '
                'kreye okenn tranzaksyon.',
            onRetry: _reload,
          );
        }

        return _Shell(
          icon: Icons.check_circle_outline,
          color: const Color(0xFF15803D),
          title: 'Pasrèl Bazik aktif (${status.mode})',
          detail:
              'Float disponib: ${status.available.toStringAsFixed(2)} ${status.currency}.',
          onRetry: _reload,
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w900, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF667365),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Tcheke ankò',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
            ),
        ],
      ),
    );
  }
}
