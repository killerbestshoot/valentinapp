import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Katalòg sèvis yo ak to komisyon yo.
///
/// Sèl owner an ka chanje yon to: se to sa yo ki kreye sòld nan wallet staff
/// yo lè yon tranzaksyon livre.
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
    final agentCtrl = TextEditingController(text: service.agentCommissionPct.toStringAsFixed(1));
    final ownerCtrl = TextEditingController(text: service.ownerCommissionPct.toStringAsFixed(1));
    final formKey = GlobalKey<FormState>();

    String? validatePct(String? value) {
      final n = double.tryParse((value ?? '').replaceAll(',', '.').trim());
      if (n == null || n < 0 || n > 100) return 'Ant 0 ak 100.';
      return null;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('To komisyon — ${service.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: agentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ajan (%)', suffixText: '%'),
                    validator: validatePct,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ownerCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Owner (%)', suffixText: '%'),
                    validator: validatePct,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nouvo to a aplike sou NOUVO tranzaksyon yo sèlman. '
                    'Tranzaksyon ki deja kreye kenbe to yo te pwomèt la.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
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
          ),
        ) ??
        false;

    final agent = double.tryParse(agentCtrl.text.replaceAll(',', '.').trim());
    final owner = double.tryParse(ownerCtrl.text.replaceAll(',', '.').trim());
    agentCtrl.dispose();
    ownerCtrl.dispose();

    if (!ok) return;

    try {
      await ServicesApi.instance.update(
        service.serviceId,
        agentCommissionPct: agent,
        ownerCommissionPct: owner,
      );
      _toast('To ${service.name} mete ajou.');
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
          subtitle: 'Sèvis disponib ak to komisyon yo.',
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
                              'Ajan ${service.agentCommissionPct.toStringAsFixed(1)}% • '
                              'Owner ${service.ownerCommissionPct.toStringAsFixed(1)}%'
                              '${service.gatewayBacked ? ' • via Bazik' : ' • livrezon manyèl'}',
                              style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (_isOwner) ...[
                        IconButton(
                          tooltip: 'Chanje to yo',
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
