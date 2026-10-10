import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/operations/data/reconciliation_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

const _warn = Color(0xFFB45309);
const _warnBg = Color(0xFFFBEFD9);

String _money(double v) {
  final parts = v.abs().toStringAsFixed(2).split('.');
  final d = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(' ');
    b.write(d[i]);
  }
  return '$b,${parts[1]}';
}

String _date(DateTime? at) {
  if (at == null) return '—';
  final l = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Transfè Bazik ki bloke: owner a jwenn yo sou dashboard Bazik la, epi li
/// deside — livre (ak ID Bazik la) oswa echwe (ajan an ranbouse).
class StuckTransfersPage extends StatefulWidget {
  const StuckTransfersPage({super.key});

  @override
  State<StuckTransfersPage> createState() => _StuckTransfersPageState();
}

class _StuckTransfersPageState extends State<StuckTransfersPage> {
  late Future<List<StuckTransfer>> _future = ReconciliationApi.instance.stuck();

  bool get _isOwner => AuthRepositoryProvider.instance.currentUser?.role == AppRole.owner;

  void _reload() {
    setState(() {
      _future = ReconciliationApi.instance.stuck();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _resolve(StuckTransfer t, {required bool delivered}) async {
    final decision = await showDialog<({String gatewayId, String note})>(
      context: context,
      builder: (_) => _ResolveDialog(transfer: t, delivered: delivered),
    );
    if (decision == null) return;

    try {
      if (delivered) {
        await ReconciliationApi.instance.confirmDelivered(t.transferId, gatewayId: decision.gatewayId, note: decision.note);
        _toast('Transfè a make livre.');
      } else {
        await ReconciliationApi.instance.markFailed(
          t.transferId,
          note: decision.note,
          reverseCommissions: t.txStatus == 'delivered',
        );
        _toast('Transfè a make echwe. Ajan an ranbouse ${_money(t.debit)} ${t.walletCurrency}.');
      }
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Pou verifye',
      actions: [IconButton(tooltip: 'Rafrechi', onPressed: _reload, icon: const Icon(Icons.refresh))],
      children: [
        const DashboardPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _warn),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transfè sa yo pa fini depi plis pase 15 minit. Sa ki make "Verifikasyon manyèl" '
                  'pa gen ID Bazik: sistèm nan pa ka konnen si lajan an pati. Chèche yo sou dashboard '
                  'Bazik la (dat, montan, nimewo), epi deside. Lòt yo ap rekonsilye otomatikman chak 5 minit.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StuckTransfer>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              final e = snap.error;
              return DashboardPanel(
                child: Text(e is ApiException ? e.message : '$e', style: const TextStyle(color: DashboardColors.danger)),
              );
            }
            final rows = snap.data ?? const <StuckTransfer>[];
            if (rows.isEmpty) {
              return const DashboardPanel(
                child: Row(children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                  SizedBox(width: 10),
                  Text('Pa gen transfè bloke.'),
                ]),
              );
            }
            final total = rows.fold<double>(0, (s, t) => s + t.amountHtg);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('${rows.length} transfè · ${_money(total)} HTG',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                ...rows.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StuckCard(
                        t: t,
                        canResolve: _isOwner,
                        onDelivered: () => _resolve(t, delivered: true),
                        onFailed: () => _resolve(t, delivered: false),
                        onCopy: (v) {
                          Clipboard.setData(ClipboardData(text: v));
                          _toast('Kopye: $v');
                        },
                      ),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StuckCard extends StatelessWidget {
  const _StuckCard({
    required this.t,
    required this.canResolve,
    required this.onDelivered,
    required this.onFailed,
    required this.onCopy,
  });

  final StuckTransfer t;
  final bool canResolve;
  final VoidCallback onDelivered;
  final VoidCallback onFailed;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final net = t.network == 'natcash' ? 'NatCash' : 'MonCash';
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${_money(t.amountHtg)} HTG',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DashboardColors.ink)),
              Text(net, style: const TextStyle(color: DashboardColors.muted, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _warnBg, borderRadius: BorderRadius.circular(999)),
                child: Text(t.manualReview ? 'Verifikasyon manyèl' : 'An kou',
                    style: const TextStyle(color: _warn, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              if (t.txStatus == 'delivered')
                const Text('Tranzaksyon an make livre',
                    style: TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _Field('Dat', _date(t.createdAt)),
              _Field('Benefisyè', t.receiverName.isEmpty ? '—' : t.receiverName),
              InkWell(onTap: () => onCopy(t.phone), child: _Field('Telefòn', '${t.phone}  ⧉')),
              _Field('Ajan', t.staffName.isEmpty ? '—' : t.staffName),
              _Field('Debite nan wallet', '${_money(t.debit)} ${t.walletCurrency}'),
              _Field('ID Bazik', t.gatewayId ?? 'pa genyen'),
            ],
          ),
          if (canResolve) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onDelivered,
                  style: FilledButton.styleFrom(backgroundColor: DashboardColors.brand),
                  icon: const Icon(Icons.check),
                  label: const Text('Konfime livre'),
                ),
                OutlinedButton.icon(
                  onPressed: onFailed,
                  style: OutlinedButton.styleFrom(foregroundColor: DashboardColors.danger),
                  icon: const Icon(Icons.undo),
                  label: const Text('Make echwe'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10, letterSpacing: 0.7, fontWeight: FontWeight.w800, color: DashboardColors.muted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Dyalòg desizyon an. Li posede chan li yo: yo libere lè dyalòg la fèmen nèt
/// (apre animasyon an), pa anvan.
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.transfer, required this.delivered});

  final StuckTransfer transfer;
  final bool delivered;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final delivered = widget.delivered;
    return AlertDialog(
      title: Text(delivered ? 'Konfime lajan an pati' : 'Make transfè a echwe'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_money(t.amountHtg)} HTG · ${t.receiverName} · ${t.phone}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  delivered
                      ? 'Mete ID transfè a jan li parèt sou dashboard Bazik la. Sèvè a ap mande Bazik '
                          'konfime li "completed" anvan li make l livre.'
                      : 'Fè sa SÈLMAN si transfè a pa parèt sou dashboard Bazik la. Ajan an ap '
                          'ranbouse ${_money(t.debit)} ${t.walletCurrency}. Si lajan an te pati, '
                          'antrepriz la ap pèdi l.',
                  style: TextStyle(fontSize: 13, color: delivered ? DashboardColors.muted : _warn),
                ),
                if (!delivered && t.txStatus == 'delivered') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _warnBg, borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'Tranzaksyon sa a te make livre alamen e komisyon yo te peye. '
                      'Si w konfime, tranzaksyon an pase echwe epi komisyon yo retire tou.',
                      style: TextStyle(fontSize: 12.5, color: _warn, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (delivered) ...[
                  TextFormField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(labelText: 'ID transfè Bazik', border: OutlineInputBorder()),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'ID a obligatwa.' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Poukisa? (tras desizyon an)',
                    hintText: 'Egz. Pa parèt sou dashboard Bazik 10/10',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().length < 5 ? 'Omwen 5 karaktè.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anile')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: delivered ? DashboardColors.brand : DashboardColors.danger),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (gatewayId: _idCtrl.text.trim(), note: _noteCtrl.text.trim()));
          },
          child: Text(delivered ? 'Konfime livre' : 'Make echwe epi ranbouse'),
        ),
      ],
    );
  }
}
