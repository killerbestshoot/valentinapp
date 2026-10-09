import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_base.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/data/http_auth_repository.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/pages/notifications/notifications_page.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Paramèt kont lan.
///
/// Sou backend SQLite la, chanje modpas se yon fòm dirèk — pa yon imel reset.
/// Serveur a verifye ansyen modpas la, epi li fè TOUT sesyon yo tonbe: si yon
/// moun te gen yon sesyon vòlè, li pèdi l la menm.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Dekonekte'),
            content: const Text('Eske ou vle dekonekte kounye a?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.logout),
                label: const Text('Dekonekte'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await AuthRepositoryProvider.instance.signOut();

    // Paramèt louvri ak `Navigator.push`: wout sa a rete ANWO pil GoRouter la.
    // San `go`, moun nan rete sou ekran Paramèt, "konekte" ak yon sesyon vid.
    if (context.mounted) context.go('/');
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chanje modpas'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Modpas aktyèl',
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Antre modpas aktyèl la.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouvo modpas',
                      helperText: 'Omwen 8 karaktè.',
                    ),
                    validator: (v) =>
                        (v ?? '').length < 8 ? 'Omwen 8 karaktè.' : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ou pral dekonekte sou tout aparèy apre chanjman an.',
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
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Chanje'),
              ),
            ],
          ),
        ) ??
        false;

    final currentPassword = currentCtrl.text;
    final newPassword = newCtrl.text;
    // Kontwolè yo kenbe modpas an klè: nou libere yo tou swit.
    currentCtrl.dispose();
    newCtrl.dispose();

    if (!ok) return;

    try {
      await HttpAuthRepository.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (context.mounted) {
        _toast(context, 'Modpas chanje. Konekte ankò.');
        context.go('/');
      }
    } on ApiException catch (err) {
      if (context.mounted) _toast(context, err.message);
    }
  }

  void _showAbout(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;

    showAboutDialog(
      context: context,
      applicationName: 'VOUPVAPCASH',
      applicationVersion: '1.0.0+1',
      children: [
        const SizedBox(height: 12),
        _AboutRow(label: 'Itilizatè', value: user?.email ?? '—'),
        _AboutRow(label: 'Wòl', value: user?.role.name ?? '—'),
        _AboutRow(label: 'Antrepriz', value: user?.enterpriseName ?? '—'),
        const _AboutRow(label: 'Backend', value: 'SQLite'),
        _AboutRow(label: 'Serveur', value: ApiBase.origin),
        const _AboutRow(
          label: 'Pasrèl peman',
          value: 'Bazik (MonCash / NatCash)',
        ),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;
    final isOwner = user?.role == AppRole.owner;

    return DashboardPage(
      title: 'Paramèt',
      children: [
        DashboardHero(
          icon: Icons.settings_outlined,
          title: 'VOUPVAPCASH settings',
          subtitle: user?.email ?? 'User konekte',
        ),
        const SizedBox(height: 18),
        DashboardActionTile(
          icon: Icons.security_outlined,
          title: 'Sekirite',
          subtitle: 'Chanje modpas ou',
          onTap: () => _changePassword(context),
        ),
        if (isOwner) ...[
          const SizedBox(height: 12),
          const _ExchangeMarginTile(),
          const SizedBox(height: 12),
          const _PslFallbackTile(),
        ],
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifikasyon',
          subtitle: 'Wè notifikasyon antrepriz la',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.info_outline,
          title: 'A pwopo',
          subtitle: 'Vèsyon ak konfigirasyon',
          onTap: () => _showAbout(context),
          color: const Color(0xFF525252),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.logout,
          title: 'Dekonekte',
          subtitle: 'Sòti sou kont aktyèl la',
          onTap: () => _logout(context),
          color: const Color(0xFFB91C1C),
        ),
      ],
    );
  }
}

/// Owner sèlman: pèmèt oswa koupe manyèlman PSL kòm fallback pou MonCash.
class _PslFallbackTile extends StatefulWidget {
  const _PslFallbackTile();

  @override
  State<_PslFallbackTile> createState() => _PslFallbackTileState();
}

class _PslFallbackTileState extends State<_PslFallbackTile> {
  PslFallbackSettings? _settings;
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
      final settings = await WalletApi.instance.pslFallbackSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.message;
      });
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final previous = _settings;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await WalletApi.instance.setPslFallbackEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved.enabled
              ? 'Fallback PSL MonCash aktive.'
              : 'Fallback PSL MonCash dezaktive.'),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
        _error = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final configured = settings?.configured ?? false;
    final subtitle = _loading
        ? 'Chaje…'
        : _error != null
            ? _error!
            : !configured
                ? 'PSL pa konfigire sou sèvè a.'
                : settings!.enabled
                    ? 'Si Bazik pa ka voye MonCash, PSL pran relè a (frè 7%).'
                    : 'Fallback dezaktive; se Bazik sèlman k ap sèvi.';

    return DashboardPanel(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.swap_horiz, color: Color(0xFF0F766E)),
        title: const Text(
          'Fallback MonCash via PSL',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        value: configured && settings?.enabled == true,
        onChanged: _loading || _saving || !configured ? null : _setEnabled,
      ),
    );
  }
}

/// Owner an sèlman: majin an HTG ki soustrè de chak to echanj. Egzanp: to
/// MXN 7.60, majin 0.80 → to efektif 6.80. Antrepriz la kenbe diferans la.
class _ExchangeMarginTile extends StatefulWidget {
  const _ExchangeMarginTile();

  @override
  State<_ExchangeMarginTile> createState() => _ExchangeMarginTileState();
}

class _ExchangeMarginTileState extends State<_ExchangeMarginTile> {
  static const double _maxMargin = 0.80;
  double? _current;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await WalletApi.instance.exchangeMargin();
      if (!mounted) return;
      setState(() {
        _current = value;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor() async {
    final current = _current ?? 0;
    final controller = TextEditingController(text: current.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Majin to echanj'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Montan an HTG ki soustrè de chak to echanj (max 0.80).\n'
                    'Egzanp: 7.60 HTG → 6.80 HTG si majin an 0.80.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF607064)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Majin (HTG)',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = (value ?? '').replaceAll(',', '.').trim();
                      final number = double.tryParse(text);
                      if (number == null || number < 0) {
                        return 'Antre yon valè ki pa negatif.';
                      }
                      if (number > _maxMargin) {
                        return 'Pa plis pase ${_maxMargin.toStringAsFixed(2)} HTG.';
                      }
                      return null;
                    },
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
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Anrejistre'),
              ),
            ],
          ),
        ) ??
        false;

    final newValue = double.tryParse(
      controller.text.replaceAll(',', '.').trim(),
    );
    controller.dispose();

    if (!confirmed || newValue == null) return;

    try {
      final saved = await WalletApi.instance.setExchangeMargin(newValue);
      if (!mounted) return;
      setState(() => _current = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Majin an mete sou ${saved.toStringAsFixed(2)} HTG.',
          ),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _current;
    final subtitle = _loading
        ? 'Chaje…'
        : _error != null
            ? _error!
            : value == null || value <= 0
                ? 'Pa gen majin aktive (to brit la itilize)'
                : 'Majin aktyèl: ${value.toStringAsFixed(2)} HTG pa inite';

    return DashboardActionTile(
      icon: Icons.swap_horiz_outlined,
      title: 'Majin to echanj',
      subtitle: subtitle,
      onTap: _loading ? null : _openEditor,
      color: const Color(0xFF0F766E),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
