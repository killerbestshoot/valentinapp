import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/airtime/domain/reloadly_overview.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Sante platfòm lan: baz done, pasrèl yo, solvabilite, transfè bloke.
///
/// DONE LAJAN (solvabilite, sòld Reloadly, komisyon, istorik) se OWNER SÈLMAN:
/// serveur a voye `restricted: true` bay lòt yo, e paj la di poukisa.
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
                const SizedBox(height: 12),
                _SolvencyCard(solvency: health.solvency),
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
        const SizedBox(height: 18),
        const DashboardSectionTitle(title: 'Kont Reloadly (Minit Haiti)'),
        const SizedBox(height: 12),
        AsyncView<ReloadlyOverview>(
          load: SystemApi.instance.reloadly,
          builder: (context, overview, reload) => _ReloadlySection(overview: overview),
        ),
      ],
    );
  }
}

/// Float ajan yo (dèt) kontre pwovizyon Bazik + Reloadly.
class _SolvencyCard extends StatelessWidget {
  const _SolvencyCard({required this.solvency});

  final Map<String, dynamic> solvency;

  @override
  Widget build(BuildContext context) {
    if (solvency['restricted'] == true) {
      return const _Check(
        ok: true,
        title: 'Solvabilite',
        detail: 'Rezève pou owner: se li menm ki wè chif pwovizyon yo.',
      );
    }

    final status = '${solvency['status'] ?? 'unknown'}';
    final coverage = (solvency['coverage'] as Map?)?.cast<String, dynamic>() ?? const {};
    final liabilities = (solvency['liabilities'] as Map?)?.cast<String, dynamic>() ?? const {};
    final bazik = (coverage['bazik'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reloadly = (coverage['reloadly'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reasons = ((solvency['reasons'] as List?) ?? const []).join(' · ');

    final detail = switch (status) {
      'covered' => 'Float ajan yo: ${liabilities['total']} HTG · pwovizyon: ${coverage['total']} HTG.',
      'thin' =>
        'Pwovizyon jis-jis: ${coverage['total']} HTG pou ${liabilities['total']} HTG float ajan.',
      'uncovered' =>
        'MANKE ${solvency['gap']} HTG: ${liabilities['total']} HTG float ajan pou '
            '${coverage['total']} HTG pwovizyon.',
      _ => 'Nou pa ka verifye: $reasons',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Check(ok: status == 'covered', title: 'Solvabilite', detail: detail),
        if (status != 'unknown')
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Bazik: ${bazik['available'] ?? '—'} ${bazik['currency'] ?? ''} · '
              'Reloadly: ${reloadly['available'] ?? '—'} ${reloadly['currency'] ?? ''}'
              '${reloadly['enabled'] == false ? ' (dezaktive)' : ''} — '
              'HTG Bazik la pa ka peye minit, USD Reloadly la pa ka peye MonCash.',
              style: const TextStyle(color: DashboardColors.muted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// Pèmisyon kont Reloadly la, ak sa chak pèmisyon bay.
class _ReloadlySection extends StatelessWidget {
  const _ReloadlySection({required this.overview});

  final ReloadlyOverview overview;

  @override
  Widget build(BuildContext context) {
    if (!overview.enabled) {
      return _Check(
        ok: false,
        title: 'Minit Haiti poko aktive',
        detail: overview.warning.isEmpty
            ? 'Kle Reloadly yo pa konfigire sou serveur a.'
            : overview.warning,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pèmisyon kont lan (mòd ${overview.mode})',
                style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sa kle API yo bay dwa fè. Pa gen okenn pèmisyon pou FINANSE kont lan: '
                'sa fèt sou dashboard Reloadly a.',
                style: TextStyle(color: DashboardColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: overview.permissions.map((p) => _PermissionChip(permission: p)).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Operatè Ayiti',
          section: overview.operators,
          builder: (operators) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reloadly make "Natcom Haiti Special Bundle" kòm airtime alòske
              // se yon pakè: se poutèt sa vant lan sèvi SÈLMAN ak operatè
              // otodeteksyon an bay pou nimewo a.
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Nou vann sèlman operatè otodeteksyon an bay pou yon nimewo.',
                  style: TextStyle(color: DashboardColors.muted, fontSize: 11),
                ),
              ),
              ...operators
                .map((op) => _Line(
                      label: '${op.name} #${op.operatorId}',
                      value: op.sellable
                          ? '${op.minAmount.toStringAsFixed(2)}–${op.maxAmount.toStringAsFixed(2)} '
                              '${op.senderCurrency} · 1 ${op.senderCurrency} = ${op.fxRate.toStringAsFixed(2)} HTG'
                          : '${op.kind} · ${op.status} — nou pa vann li',
                    )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Pwomosyon',
          section: overview.promotions,
          builder: (promotions) => promotions.isEmpty
              ? const Text('Pa gen pwomosyon kounye a.',
                  style: TextStyle(color: DashboardColors.muted, fontSize: 12))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: promotions
                      .map((p) => _Line(label: '${p['title'] ?? ''}', value: '${p['endDate'] ?? ''}'))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Sòld kont lan',
          section: overview.balance,
          builder: (balance) => _Line(
            label: balance.low ? 'Sòld BA' : 'Sòld',
            value: '${balance.balance.toStringAsFixed(2)} ${balance.currency}'
                '${balance.lowBalanceThreshold > 0 ? ' (papòt ${balance.lowBalanceThreshold.toStringAsFixed(2)})' : ''}',
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Komisyon (maj sou chak rechaj)',
          section: overview.commissions,
          builder: (commissions) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: commissions
                .map((c) => _Line(
                      label: c.operatorName,
                      value: '${c.percentage.toStringAsFixed(2)}% '
                          '(montan lokal: ${c.localPercentage.toStringAsFixed(2)}%)',
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Dènye rechaj yo',
          section: overview.history,
          builder: (history) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: history
                .map((t) => _Line(
                      label: '${t.date} · ${t.operatorName}',
                      value: '${t.requestedAmount.toStringAsFixed(2)} ${t.requestedCurrency} → '
                          '${t.deliveredAmount.toStringAsFixed(2)} ${t.deliveredCurrency} · ${t.status}',
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.permission});

  final ReloadlyPermission permission;

  @override
  Widget build(BuildContext context) {
    final color = permission.granted ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(permission.granted ? Icons.check : Icons.close, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            permission.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
          if (permission.ownerOnly) ...[
            const SizedBox(width: 6),
            const Text('owner', style: TextStyle(color: DashboardColors.muted, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

/// Yon seksyon: done yo, oswa rezon ki fè yo pa la.
class _SectionCard<T> extends StatelessWidget {
  const _SectionCard({required this.title, required this.section, required this.builder});

  final String title;
  final ReloadlySection<T> section;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (section.ok && section.data != null) {
      body = builder(section.data as T);
    } else if (section.restricted) {
      body = const Text('Rezève pou owner.',
          style: TextStyle(color: DashboardColors.muted, fontSize: 12));
    } else if (section.missingScope) {
      body = const Text('Kle API yo pa gen pèmisyon sa a.',
          style: TextStyle(color: Color(0xFFB45309), fontSize: 12));
    } else {
      body = Text('Reloadly pa reponn (${section.error}).',
          style: const TextStyle(color: Color(0xFFB45309), fontSize: 12));
    }

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.ink)),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: DashboardColors.ink, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
