import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../widgets/dashboard_ui.dart';
import '../../data/wallet_api.dart';

/// To jounen an sou ekran prensipal la: USD, MXN ak HTG youn kont lòt.
///
/// Se MENM to serveur a sèvi pou konvèti (majin owner an deja soustrè), pa
/// yon kalkil apa — sa ajan an wè isit la se sa kliyan an pral peye.
class ExchangeRatesCard extends StatefulWidget {
  const ExchangeRatesCard({super.key});

  @override
  State<ExchangeRatesCard> createState() => _ExchangeRatesCardState();
}

class _ExchangeRatesCardState extends State<ExchangeRatesCard> {
  late Future<ExchangeRatesSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = WalletApi.instance.ratesSnapshot();
  }

  void _reload() {
    setState(() {
      _future = WalletApi.instance.ratesSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: FutureBuilder<ExchangeRatesSnapshot>(
        future: _future,
        builder: (context, snap) {
          final title = DashboardSectionTitle(
            title: 'To echanj jodi a',
            action: IconButton(
              tooltip: 'Rafrechi to yo',
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: DashboardColors.brand),
            ),
          );

          if (snap.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
            );
          }

          if (snap.hasError) {
            final error = snap.error;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 8),
                Text(
                  error is ApiException ? error.message : 'To yo pa disponib.',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ],
            );
          }

          final data = snap.data!;
          final pairs = [
            _Pair('USD', 'HTG', data.cross('USD', 'HTG')),
            _Pair('MXN', 'HTG', data.cross('MXN', 'HTG')),
            _Pair('USD', 'MXN', data.cross('USD', 'MXN')),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final tiles = pairs.map((p) => _RateTile(pair: p)).toList();

                  if (!wide) {
                    return Column(
                      children: [
                        for (final tile in tiles) ...[
                          tile,
                          if (tile != tiles.last) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (final tile in tiles) ...[
                        Expanded(child: tile),
                        if (tile != tiles.last) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _Footer(updatedAt: data.updatedAt, stale: data.stale),
            ],
          );
        },
      ),
    );
  }
}

class _Pair {
  const _Pair(this.from, this.to, this.rate);

  final String from;
  final String to;
  final double? rate;
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.pair});

  final _Pair pair;

  @override
  Widget build(BuildContext context) {
    final rate = pair.rate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashboardColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 ${pair.from}',
            style: const TextStyle(
              color: DashboardColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rate == null ? '—' : '${_format(rate)} ${pair.to}',
            style: const TextStyle(
              color: DashboardColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rate == null || rate == 0
                ? 'To pa disponib'
                : '1 ${pair.to} = ${_format(1 / rate, digits: 4)} ${pair.from}',
            style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _format(double value, {int digits = 2}) =>
      value.toStringAsFixed(digits);
}

class _Footer extends StatelessWidget {
  const _Footer({required this.updatedAt, required this.stale});

  final DateTime? updatedAt;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final at = updatedAt;
    final when = at == null
        ? 'dat enkoni'
        : '${_two(at.day)}/${_two(at.month)}/${at.year} '
            '${_two(at.hour)}:${_two(at.minute)}';

    return Row(
      children: [
        Icon(
          stale ? Icons.warning_amber_rounded : Icons.schedule,
          size: 14,
          color: stale ? const Color(0xFFB45309) : DashboardColors.muted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            stale ? 'To yo pa ajou (dènye: $when)' : 'Mete ajou: $when',
            style: TextStyle(
              color: stale ? const Color(0xFFB45309) : DashboardColors.muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
