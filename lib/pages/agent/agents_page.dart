import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/admin/presentation/pages/create_agent_screen.dart';
import 'package:mon_premye_app/features/users/data/users_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Lis staff antrepriz la, ak sòld wallet yo.
///
/// Sòld la vini nan menm rekèt ak staff la (yon `JOIN` sou serveur a): anvan,
/// chak liy te deklanche yon lekti Firestore separe.
class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  /// Deviz admin nan ka tape ladan. Serveur a konvèti vè deviz wallet la.
  static const creditCurrencies = ['HTG', 'MXN', 'USD'];

  late Future<List<StaffMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = UsersApi.instance.list();
  }

  void _reload() {
    // Apre yon `await`, ekran an ka deja fèmen.
    if (!mounted) return;
    setState(() {
      _future = UsersApi.instance.list();
    });
  }

  Future<void> _toggleActive(StaffMember staff) async {
    try {
      await UsersApi.instance.setActive(staff.uid, !staff.isActive);
      _reload();
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }

  Future<void> _delete(StaffMember staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Efase kont sa a?'),
        content: Text(
          '${staff.label} (${staff.email}) pral efase nèt. '
          'Sa posib sèlman si kont lan poko janm fè okenn tranzaksyon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anile'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Efase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await UsersApi.instance.delete(staff.uid);
      _toast('${staff.label} efase.');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mete kòb nan wallet yon staff, dirèkteman.
  ///
  /// Yon wallet gen YON SÈL deviz. Admin nan ka tape nan HTG, MXN oswa USD:
  /// serveur a konvèti vè deviz wallet la ak to ki estoke a. Nou montre
  /// konvèsyon an anvan validasyon — pèsonn pa dwe dekouvri li apre.
  ///
  /// Sa pase pa menm chemen ak yon rechaj apwouve (`settleTopup`): sòld la ak
  /// liy rejis la ekri nan menm tranzaksyon.
  Future<void> _addFunds(StaffMember staff) async {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Map<String, double> rates;
    try {
      rates = await WalletApi.instance.rates();
    } on ApiException catch (err) {
      _toast(err.message);
      return;
    }

    if (!mounted) return;

    var inputCurrency = staff.currency;

    /// Konbyen sa fè nan deviz wallet la.
    double? converted(String text) {
      final amount = double.tryParse(text.replaceAll(',', '.').trim());
      if (amount == null || amount <= 0) return null;
      if (inputCurrency == staff.currency) return amount;

      final from = rates[inputCurrency];
      final to = rates[staff.currency];
      if (from == null || to == null || to == 0) return null;

      return amount * from / to;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final preview = converted(amountCtrl.text);

              return AlertDialog(
                title: Text('Ajoute fon — ${staff.label}'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sòld aktyèl: ${staff.balance.toStringAsFixed(2)} ${staff.currency}',
                        style: const TextStyle(color: DashboardColors.muted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: amountCtrl,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Montan pou ajoute',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                              validator: (value) {
                                final amount = double.tryParse(
                                  (value ?? '').replaceAll(',', '.').trim(),
                                );
                                if (amount == null || amount <= 0) {
                                  return 'Antre yon montan pi gran pase 0.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 104,
                            child: DropdownButtonFormField<String>(
                              initialValue: inputCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Deviz',
                              ),
                              items: _AgentsPageState.creditCurrencies
                                  .map((code) => DropdownMenuItem(
                                        value: code,
                                        child: Text(code),
                                      ))
                                  .toList(),
                              onChanged: (value) => setDialogState(() {
                                inputCurrency = value ?? staff.currency;
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (inputCurrency != staff.currency) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DashboardColors.soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            preview == null
                                ? 'Antre yon montan pou wè konvèsyon an.'
                                : 'Wallet la ap resevwa '
                                    '${preview.toStringAsFixed(2)} ${staff.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: DashboardColors.ink,
                            ),
                          ),
                        ),
                      ],
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
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    child: const Text('Ajoute'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirmed) return;

    final amount = double.parse(amountCtrl.text.replaceAll(',', '.').trim());

    try {
      await WalletApi.instance.requestTopup(
        targetUid: staff.uid,
        amount: amount,
        currency: inputCurrency,
        note: 'Fon ajoute dirèkteman',
        autoApprove: true,
      );

      _toast('${amount.toStringAsFixed(2)} $inputCurrency ajoute.');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Agents',
      children: [
        const DashboardHero(
          icon: Icons.groups_outlined,
          title: 'Agents',
          subtitle: 'Manage field staff and live balances.',
        ),
        const SizedBox(height: 18),
        DashboardActionTile(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Nouvo ajan',
          subtitle: 'Kreye yon kont ajan nan antrepriz ou a',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateAgentScreen()),
            );
            _reload();
          },
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: FutureBuilder<List<StaffMember>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                final error = snap.error;
                return Text(
                  error is ApiException ? error.message : '$error',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                );
              }

              final staff = snap.data ?? const <StaffMember>[];
              if (staff.isEmpty) return const Text('Pa gen staff jwenn.');

              return Column(
                children: staff
                    .map((member) => _StaffRow(
                          staff: member,
                          onToggle: () => _toggleActive(member),
                          onAddFunds: () => _addFunds(member),
                          onDelete: () => _delete(member),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staff,
    required this.onToggle,
    required this.onAddFunds,
    required this.onDelete,
  });

  final StaffMember staff;
  final VoidCallback onToggle;
  final VoidCallback onAddFunds;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pending = staff.isPendingApproval;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pending
                  ? const Color(0xFFFFF4E5)
                  : DashboardColors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              pending
                  ? Icons.hourglass_bottom
                  : (staff.isActive
                      ? Icons.person_outline
                      : Icons.person_off_outlined),
              color: pending
                  ? const Color(0xFFB45309)
                  : DashboardColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        staff.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DashboardColors.ink,
                          fontWeight: FontWeight.w900,
                          decoration: staff.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Text(
                          'Tann apwobasyon',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${staff.email} | ${staff.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DashboardColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!pending)
            Text(
              '${staff.balance.toStringAsFixed(2)} ${staff.currency}',
              style: const TextStyle(
                color: DashboardColors.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (pending)
            FilledButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Apwouve'),
              style: FilledButton.styleFrom(
                backgroundColor: DashboardColors.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Ajoute fon',
              onPressed: onAddFunds,
              icon: const Icon(
                Icons.add_card_outlined,
                color: DashboardColors.brand,
              ),
            ),
            IconButton(
              tooltip: staff.isActive ? 'Dezaktive' : 'Aktive',
              onPressed: onToggle,
              icon: Icon(
                staff.isActive
                    ? Icons.toggle_on
                    : Icons.toggle_off_outlined,
                color: staff.isActive
                    ? DashboardColors.brand
                    : DashboardColors.muted,
              ),
            ),
          ],
          // Owner an pa efasab depi isit la; serveur a refize tou si kont lan
          // deja gen istorik.
          if (staff.role != 'owner')
            IconButton(
              tooltip: 'Efase',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB91C1C),
              ),
            ),
        ],
      ),
    );
  }
}
