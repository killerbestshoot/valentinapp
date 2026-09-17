import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';

import '../../domain/payment_models.dart';

/// Minimòm yon rezo, konvèti nan deviz ajan an — AVAN li tape yon montan.
///
/// NatCash refize tout transfè anba 3 998 HTG. San avètisman sa a, ajan an
/// tape 20 USD (2 640 HTG), peze, epi li dekouvri refi a sèlman apre — e
/// ansyen fòm nan te gen tan kreye yon tranzaksyon `pending` òfelen.
class NetworkMinimumNotice extends StatefulWidget {
  const NetworkMinimumNotice({
    super.key,
    required this.network,
    required this.currency,
    this.loadRates,
  });

  final PaymentNetwork network;

  /// Deviz ajan an chwazi a.
  final String currency;

  /// Pou tès yo. Default: `WalletApi.instance.rates`.
  final Future<Map<String, double>> Function()? loadRates;

  /// Minimòm nan nan yon deviz, awondi an SANTIM ANLE.
  ///
  /// An wo, pa o pi pre: 3 998 HTG / 132 = 30,2878. 30,29 USD bay 3 998,28 HTG
  /// e li pase. Yon awondi o pi pre ta ka bay yon montan ki tonbe anba limit
  /// la pou yon lòt to.
  static double minimumIn(PaymentNetwork network, double rateToHtg) {
    if (rateToHtg <= 0) return 0;
    return (network.minimumHtg / rateToHtg * 100).ceil() / 100;
  }

  @override
  State<NetworkMinimumNotice> createState() => _NetworkMinimumNoticeState();
}

class _NetworkMinimumNoticeState extends State<NetworkMinimumNotice> {
  Map<String, double>? _rates;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rates = await (widget.loadRates ?? WalletApi.instance.rates)();
      if (mounted) setState(() => _rates = rates);
    } catch (_) {
      // San to, avètisman an rete valab an HTG.
    }
  }

  String _thousands(double value) {
    final digits = value.toStringAsFixed(0);
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final network = widget.network;
    final currency = widget.currency.toUpperCase();
    final rate = _rates?[currency];
    final converted = currency != 'HTG' && rate != null && rate > 0
        ? NetworkMinimumNotice.minimumIn(network, rate)
        : null;

    final scheme = Theme.of(context).colorScheme;
    final minimumHtg = '${_thousands(network.minimumHtg)} HTG';

    return Container(
      key: const ValueKey('network-minimum-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  converted == null
                      ? '${network.label}: minimòm $minimumHtg'
                      : '${network.label}: minimòm $minimumHtg '
                          '(${converted.toStringAsFixed(2)} $currency)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  network == PaymentNetwork.natcash
                      ? 'Anba montan sa a, NatCash refize transfè a. Pou yon ti '
                          'montan, chwazi MonCash (minimòm '
                          '${_thousands(PaymentNetwork.moncash.minimumHtg)} HTG).'
                      : 'Anba montan sa a, ${network.label} refize transfè a.',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
