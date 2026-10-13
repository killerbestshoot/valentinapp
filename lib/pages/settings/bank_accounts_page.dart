import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Owner/admin: kont bank antrepriz la. Se sa ajan yo wè lè yo chwazi
/// "Virement bancaire" pou yon rechaj.
class BankAccountsPage extends StatefulWidget {
  const BankAccountsPage({super.key});

  @override
  State<BankAccountsPage> createState() => _BankAccountsPageState();
}

class _BankAccountsPageState extends State<BankAccountsPage> {
  static const _max = 5;

  List<BankAccount> _accounts = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await WalletApi.instance.bankAccounts();
      if (mounted) setState(() => _accounts = accounts);
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(List<BankAccount> next, String done) async {
    setState(() => _saving = true);
    try {
      final saved = await WalletApi.instance.saveBankAccounts(next);
      if (!mounted) return;
      setState(() => _accounts = saved);
      _toast(done);
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([int? index]) async {
    final current = index == null ? null : _accounts[index];
    final result = await showDialog<BankAccount>(
      context: context,
      builder: (_) => _BankAccountDialog(initial: current),
    );
    if (result == null) return;

    final next = [..._accounts];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    await _save(next, index == null ? 'Kont lan ajoute.' : 'Kont lan mete ajou.');
  }

  Future<void> _delete(int index) async {
    final account = _accounts[index];
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Retire kont sa a?'),
            content: Text('${account.bankName} · ${account.accountNumber}\nAjan yo p ap wè l ankò.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anile')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retire')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await _save([..._accounts]..removeAt(index), 'Kont lan retire.');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Kont bank',
      children: [
        const DashboardHero(
          icon: Icons.account_balance_outlined,
          title: 'Kont bank antrepriz la',
          subtitle: 'Ajan yo vire sou kont sa yo pou yo rechaje wallet yo. '
              'Ou verifye referans lan sou relve bank lan anvan ou apwouve.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C)))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (_accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Pa gen kont bank ankò. Ajan yo pa ka chwazi virement bancaire.',
                            style: TextStyle(color: DashboardColors.muted),
                          ),
                        ),
                      for (var i = 0; i < _accounts.length; i++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: DashboardColors.soft,
                            child: Icon(Icons.account_balance, color: DashboardColors.brand),
                          ),
                          title: Text('${_accounts[i].bankName} · ${_accounts[i].currency}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${_accounts[i].accountName}\n${_accounts[i].accountNumber}'),
                          isThreeLine: true,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Modifye',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _saving ? null : () => _edit(i),
                            ),
                            IconButton(
                              tooltip: 'Retire',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _saving ? null : () => _delete(i),
                            ),
                          ]),
                        ),
                        const Divider(),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _saving || _accounts.length >= _max ? null : () => _edit(),
                          icon: const Icon(Icons.add),
                          label: Text(_accounts.length >= _max ? '$_max kont maksimòm' : 'Ajoute yon kont'),
                        ),
                      ),
                    ]),
        ),
      ],
    );
  }
}

class _BankAccountDialog extends StatefulWidget {
  const _BankAccountDialog({this.initial});

  final BankAccount? initial;

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _bankCtrl = TextEditingController(text: widget.initial?.bankName);
  late final _nameCtrl = TextEditingController(text: widget.initial?.accountName);
  late final _numberCtrl = TextEditingController(text: widget.initial?.accountNumber);
  late final _instrCtrl = TextEditingController(text: widget.initial?.instructions);
  late String _currency = widget.initial?.currency ?? 'HTG';

  @override
  void dispose() {
    for (final c in [_bankCtrl, _nameCtrl, _numberCtrl, _instrCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Obligatwa.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouvo kont bank' : 'Modifye kont lan'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _bankCtrl,
                decoration: const InputDecoration(labelText: 'Bank', hintText: 'Egz. Unibank, Sogebank, BNC'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Non sou kont lan'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(labelText: 'Nimewo kont lan'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'HTG', label: Text('HTG')),
                  ButtonSegment(value: 'USD', label: Text('USD')),
                  ButtonSegment(value: 'MXN', label: Text('MXN')),
                ],
                selected: {_currency},
                onSelectionChanged: (s) => setState(() => _currency = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Enstriksyon (opsyonèl)',
                  hintText: 'Egz. Mete non ou nan deskripsyon virement an',
                ),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anile')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              BankAccount(
                id: widget.initial?.id ?? '',
                bankName: _bankCtrl.text.trim(),
                accountName: _nameCtrl.text.trim(),
                accountNumber: _numberCtrl.text.trim(),
                currency: _currency,
                instructions: _instrCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Anrejistre'),
        ),
      ],
    );
  }
}
