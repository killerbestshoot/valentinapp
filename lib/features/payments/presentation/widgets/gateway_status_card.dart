import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/operations/data/operations_api.dart';

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

  /// Sòld twa pasrèl yo (Bazik, PSL, Reloadly) — owner sèlman (solvabilite).
  late Future<SystemHealth> _health;

  PaymentGateway get _gateway => widget.gateway ?? PaymentGatewayProvider.instance;

  @override
  void initState() {
    super.initState();
    _future = _gateway.status();
    _health = SystemApi.instance.health();
  }

  void _reload() {
    // Fòm blòk obligatwa: `setState(() => _future = ...)` retounen Future a,
    // epi Flutter leve yon erè paske li kwè nou fè travay async ladan.
    setState(() {
      _future = _gateway.status();
      _health = SystemApi.instance.health();
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
          extra: _GatewayBalances(future: _health),
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
    this.extra,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  /// Kontni anba detay la (sòld pasrèl yo).
  final Widget? extra;

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
                if (extra != null) ...[const SizedBox(height: 10), extra!],
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

/// Twa sòld yo kòt a kòt: Bazik (MonCash/NatCash), PSL (relè), Reloadly (minit).
/// Chif pwovizyon yo rezève pou owner: pou yon admin, anyen pa parèt.
class _GatewayBalances extends StatelessWidget {
  const _GatewayBalances({required this.future});

  final Future<SystemHealth> future;

  static String _fmt(num v) {
    final parts = v.toStringAsFixed(2).split('.');
    final d = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    return '$d,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SystemHealth>(
      future: future,
      builder: (context, snap) {
        final solvency = snap.data?.solvency ?? const {};
        final coverage = (solvency['coverage'] as Map?) ?? const {};
        if (coverage.isEmpty) return const SizedBox.shrink();
        Map g(String k) => (coverage[k] as Map?) ?? const {};
        final bazik = g('bazik');
        final psl = g('psl');
        final reloadly = g('reloadly');

        String value(Map m, String fallbackCurrency) {
          if (m['configured'] == false) return 'pa konfigire';
          final available = m['available'];
          if (available is! num) return m['enabled'] == false ? 'dezaktive' : 'pa reponn';
          return '${_fmt(available)} ${m['currency'] ?? fallbackCurrency}';
        }

        final tiles = <(String, String, String, String?)>[
          ('Bazik', 'MonCash · NatCash', value(bazik, 'HTG'), null),
          ('PSL', psl['enabled'] == true ? 'Relè aktif' : 'Relè fèmen', value(psl, 'HTG'),
              psl['configured'] == true && psl['enabled'] != true ? 'pa konte nan kouvèti a' : null),
          ('Reloadly', 'Minit', value(reloadly, 'USD'),
              reloadly['htg'] is num && reloadly['currency'] != 'HTG' ? '≈ ${_fmt(reloadly['htg'] as num)} HTG' : null),
        ];
        return LayoutBuilder(builder: (context, box) {
          final cards = [
            for (final t in tiles)
              Container(
                key: ValueKey('balance-${t.$1}'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDE8D8)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t.$1} · ${t.$2}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF667365), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(t.$3, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF172116))),
                  if (t.$4 != null) Text(t.$4!, style: const TextStyle(fontSize: 11, color: Color(0xFF667365))),
                ]),
              ),
          ];
          if (box.maxWidth < 420) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 6), child: c),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ]);
        });
      },
    );
  }
}
