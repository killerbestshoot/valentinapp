import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Katalòg sèvis yo ak frè platfòm nan.
///
/// Sèl owner an ka chanje frè a: se nan frè sa a komisyon ajan an ak pati
/// owner a soti lè yon tranzaksyon livre.

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');
class ServiceCatalogPage extends StatefulWidget {
  const ServiceCatalogPage({super.key});

  @override
  State<ServiceCatalogPage> createState() => _ServiceCatalogPageState();
}

class _ServiceCatalogPageState extends State<ServiceCatalogPage> {
  final _listKey = GlobalKey<AsyncViewState<List<ServiceItem>>>();

  bool get _isOwner => AuthRepositoryProvider.instance.currentUser?.role == AppRole.owner;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(ServiceItem service) async {
    final feeCtrl = TextEditingController(text: _fmt(service.feePct));
    final minCtrl = TextEditingController(text: _fmt(service.feeMinHtg));
    final shareCtrl = TextEditingController(text: _fmt(service.agentSharePct));
    final formKey = GlobalKey<FormState>();

    double? parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '.').trim());

    String? validateRange(String? value, double min, double max) {
      final n = double.tryParse((value ?? '').replaceAll(',', '.').trim());
      if (n == null || n < min || n > max) return 'Ant ${_fmt(min)} ak ${_fmt(max)}.';
      return null;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setLocal) {
              final fee = parse(feeCtrl) ?? 0;
              final share = parse(shareCtrl) ?? 0;
              // Egzanp lan: 2000 MXN, menm jan owner a panse l.
              const example = 2000.0;
              final feeAmount = example * fee / 100;
              final agentPart = feeAmount * share / 100;
              final ownerPart = feeAmount - agentPart;
              final margin = fee * (100 - share) / 100 - service.gatewayCostPct;

              return AlertDialog(
                title: Text('Frè — ${service.name}'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: feeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Frè sou chak tranzaksyon',
                            suffixText: '%',
                            helperText: 'Obligatwa. Kliyan an peye l oswa li dedwi sou montan an.',
                          ),
                          validator: (v) => validateRange(v, 0.5, 50),
                          onChanged: (_) => setLocal(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Frè minimòm',
                            suffixText: 'HTG',
                            helperText: 'Pou ti montan yo. 0 = pa gen minimòm.',
                          ),
                          validator: (v) => validateRange(v, 0, 100000),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: shareCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Pati ajan an nan frè a',
                            suffixText: '%',
                            helperText: 'Owner a pran rès la, epi li peye frè pasrèl la ladan l.',
                          ),
                          validator: (v) => validateRange(v, 0, 100),
                          onChanged: (_) => setLocal(() {}),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DashboardColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DashboardColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Egzanp: ${_fmt(fee)}% sou 2000 MXN = ${_fmt(feeAmount)} MXN',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text('Ajan an: ${_fmt(agentPart)} MXN'),
                              Text('Owner a: ${_fmt(ownerPart)} MXN'
                                  '${service.gatewayCostPct > 0 ? ', mwens ~${_fmt(example * service.gatewayCostPct / 100)} MXN pasrèl' : ''}'),
                            ],
                          ),
                        ),
                        if (service.gatewayCostPct > 0) ...[
                          const SizedBox(height: 10),
                          _MarginNote(margin: margin, gatewayPct: service.gatewayCostPct),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Nouvo frè a aplike sou NOUVO tranzaksyon yo sèlman. '
                          'Tranzaksyon ki deja kreye kenbe frè yo te pwomèt la.',
                          style: TextStyle(fontSize: 12, color: DashboardColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Anile'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Anrejistre'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    final feePct = parse(feeCtrl);
    final feeMin = parse(minCtrl);
    final share = parse(shareCtrl);
    feeCtrl.dispose();
    minCtrl.dispose();
    shareCtrl.dispose();

    if (!ok) return;

    try {
      await ServicesApi.instance.update(
        service.serviceId,
        feePct: feePct,
        feeMinHtg: feeMin,
        agentSharePct: share,
      );
      _toast('Frè ${service.name} mete ajou.');
      _listKey.currentState?.reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  Future<void> _toggle(ServiceItem service) async {
    try {
      await ServicesApi.instance.update(service.serviceId, isActive: !service.isActive);
      _listKey.currentState?.reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Sèvis',
      children: [
        const DashboardHero(
          icon: Icons.tune_outlined,
          title: 'Katalòg sèvis',
          subtitle: 'Sèvis disponib, frè chak tranzaksyon ak pati ajan an.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: AsyncView<List<ServiceItem>>(
            key: _listKey,
            load: ServicesApi.instance.list,
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Pa gen sèvis.',
            builder: (context, rows, _) => Column(
              children: rows.map((service) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        service.gatewayBacked ? Icons.bolt : Icons.storefront_outlined,
                        color: service.isActive ? DashboardColors.brand : DashboardColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: DashboardColors.ink,
                                decoration:
                                    service.isActive ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              'Frè ${_fmt(service.feePct)}%'
                              '${service.feeMinHtg > 0 ? ' (min ${_fmt(service.feeMinHtg)} HTG)' : ''} • '
                              'Ajan ${_fmt(service.agentSharePct)}% frè a'
                              '${service.gatewayBacked ? ' • via Bazik' : ' • livrezon manyèl'}',
                              style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                            ),
                            if (service.gatewayCostPct > 0)
                              Text(
                                'Maj owner: ${service.ownerMarginPct >= 0 ? '+' : ''}${_fmt(service.ownerMarginPct)}% '
                                'apre pasrèl (~${_fmt(service.gatewayCostPct)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: service.ownerMarginPct < 0
                                      ? DashboardColors.danger
                                      : DashboardColors.brand,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isOwner) ...[
                        IconButton(
                          tooltip: 'Chanje frè a',
                          onPressed: () => _edit(service),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: service.isActive ? 'Dezaktive' : 'Aktive',
                          onPressed: () => _toggle(service),
                          icon: Icon(
                            service.isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                            color: service.isActive ? DashboardColors.brand : DashboardColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avètisman maj: owner a dwe wè l pèdi lajan ANVAN li anrejistre.
class _MarginNote extends StatelessWidget {
  const _MarginNote({required this.margin, required this.gatewayPct});

  final double margin;
  final double gatewayPct;

  @override
  Widget build(BuildContext context) {
    final loss = margin < 0;
    final color = loss ? DashboardColors.danger : DashboardColors.brand;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(loss ? Icons.warning_amber_rounded : Icons.check_circle_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            loss
                ? 'Pati ou pa kouvri pasrèl la (~${_fmt(gatewayPct)}%): ou pèdi ${_fmt(-margin)}% '
                    'sou chak transfè. Monte frè a oswa bese pati ajan an.'
                : 'Ou kenbe ${_fmt(margin)}% montan an apre ajan an ak pasrèl la (~${_fmt(gatewayPct)}%).',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
