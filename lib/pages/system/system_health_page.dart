import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Sante platfòm lan: baz done, pasrèl Bazik, transfè bloke, komisyon an reta.
class SystemHealthPage extends StatelessWidget {
  const SystemHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Sante sistèm',
      children: [
        const DashboardHero(
          icon: Icons.monitor_heart_outlined,
          title: 'Sante sistèm',
          subtitle: 'Eta baz done a, pasrèl la ak operasyon ki bloke.',
        ),
        const SizedBox(height: 18),
        AsyncView<SystemHealth>(
          load: SystemApi.instance.health,
          builder: (context, health, reload) {
            final gateway = health.gateway;
            final data = health.data;
            final stuck = (data['stuckTransfers'] as num?)?.toInt() ?? 0;
            final pendingCommissions = (data['pendingCommissions'] as num?)?.toInt() ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Check(
                  ok: health.healthy,
                  title: health.healthy ? 'Tout bagay nòmal' : 'Gen pwoblèm ki bezwen atansyon',
                  detail: '',
                ),
                const SizedBox(height: 12),
                _Check(
                  ok: health.database['ok'] == true,
                  title: 'Baz done',
                  detail: '${health.database['file'] ?? health.database['error'] ?? ''}',
                ),
                const SizedBox(height: 12),
                _Check(
                  ok: gateway['ok'] == true && gateway['funded'] == true,
                  title: 'Pasrèl Bazik (${gateway['mode'] ?? '—'})',
                  detail: gateway['ok'] == true
                      ? 'Float: ${gateway['available']} ${gateway['currency']}'
                          '${gateway['funded'] == true ? '' : ' — VID, okenn transfè p ap pati'}'
                      : '${gateway['error'] ?? 'pa reponn'}',
                ),
                const SizedBox(height: 12),
                _Check(
                  ok: stuck == 0,
                  title: 'Transfè bloke',
                  detail: stuck == 0
                      ? 'Okenn transfè bloke plis pase 1 èdtan.'
                      : '$stuck transfè an verifikasyon depi plis pase 1 èdtan.',
                ),
                const SizedBox(height: 12),
                _Check(
                  ok: pendingCommissions == 0,
                  title: 'Komisyon an reta',
                  detail: pendingCommissions == 0
                      ? 'Tout komisyon yo aplike.'
                      : '$pendingCommissions tranzaksyon livre san komisyon.',
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tcheke ankò'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.title, required this.detail});

  final bool ok;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF15803D) : const Color(0xFFB45309);

    return DashboardPanel(
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                if (detail.isNotEmpty)
                  Text(detail,
                      style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
