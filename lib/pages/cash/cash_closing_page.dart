import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/cash/data/cash_api.dart';
import 'package:mon_premye_app/pages/dashboard/owner_analytics_section.dart' show fmtMoney;
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

const _ok = Color(0xFF1F7A3A);
const _okBg = Color(0xFFE3F3E6);
const _warn = Color(0xFFB86E00);
const _warnBg = Color(0xFFFFF3DC);
const _crit = Color(0xFFB42318);
const _critBg = Color(0xFFFDECEA);

/// AAAA-MM-JJ → JJ/MM/AAAA.
String _day(String iso) => iso.length == 10 ? '${iso.substring(8)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}' : iso;

String _isoShift(String iso, int days) {
  final d = DateTime.utc(int.parse(iso.substring(0, 4)), int.parse(iso.substring(5, 7)), int.parse(iso.substring(8)));
  return d.add(Duration(days: days)).toIso8601String().substring(0, 10);
}

double _num(String v) => double.tryParse(v.replaceAll(',', '.').replaceAll(' ', '').trim()) ?? 0;

String _signed(double v, String cur) => v == 0 ? '0 $cur' : '${v > 0 ? '+' : '−'}${fmtMoney(v.abs())} $cur';

Color _varColor(double v) => v == 0 ? _ok : (v < 0 ? _crit : _warn);

/// Fèmti kès: ajan an konte kach li chak jou; owner/admin valide.
///
/// Kès atann = fon kès + lavant (sèvè a kalkile yo) − depo bay pwopriyetè a.
class CashClosingPage extends StatefulWidget {
  const CashClosingPage({super.key});

  @override
  State<CashClosingPage> createState() => _CashClosingPageState();
}

class _CashClosingPageState extends State<CashClosingPage> {
  bool get _isManager {
    final role = AuthRepositoryProvider.instance.currentUser?.role;
    return role == AppRole.owner || role == AppRole.admin;
  }

  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final manager = _isManager;
    return DashboardPage(
      title: 'Fèmen kès',
      children: [
        DashboardHero(
          icon: Icons.point_of_sale_outlined,
          title: 'Fèmen kès',
          subtitle: manager
              ? 'Kontwole kach chak ajan, chak jou: kès atann, kach konte ak ekar.'
              : 'Konte kach ou nan fen jounen an, pa deviz, epi voye l bay administratè a.',
        ),
        const SizedBox(height: 18),
        if (manager) ...[
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: false, icon: Icon(Icons.fact_check_outlined, size: 18), label: Text('Fèmti ajan yo')),
              ButtonSegment(value: true, icon: Icon(Icons.person_outline, size: 18), label: Text('Kès mwen')),
            ],
            selected: {_mine},
            onSelectionChanged: (s) => setState(() => _mine = s.first),
          ),
          const SizedBox(height: 18),
        ],
        if (!manager || _mine) const _MyCashView() else const _ClosingsView(),
      ],
    );
  }
}

// ============================================================ kès mwen

class _Row {
  _Row(this.currency,
      {double opening = 0,
      double deposit = 0,
      double? counted,
      this.sales = 0,
      this.txCount = 0,
      this.pendingCount = 0,
      this.refundedCount = 0})
      : opening = TextEditingController(text: opening == 0 ? '' : _plain(opening)),
        deposit = TextEditingController(text: deposit == 0 ? '' : _plain(deposit)),
        counted = TextEditingController(text: counted == null ? '' : _plain(counted));

  final String currency;
  final TextEditingController opening;
  final TextEditingController deposit;
  final TextEditingController counted;
  final double sales;
  final int txCount;
  final int pendingCount;
  final int refundedCount;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double get expected => _num(opening.text) + sales - _num(deposit.text);
  bool get hasCount => counted.text.trim().isNotEmpty;
  double get variance => _num(counted.text) - expected;

  void dispose() {
    opening.dispose();
    deposit.dispose();
    counted.dispose();
  }
}

class _MyCashView extends StatefulWidget {
  const _MyCashView();

  @override
  State<_MyCashView> createState() => _MyCashViewState();
}

class _MyCashViewState extends State<_MyCashView> {
  static const _extraCurrencies = ['HTG', 'USD', 'MXN', 'DOP', 'CLP', 'BRL'];

  final _note = TextEditingController();
  String? _date;
  String? _today;
  CashClosing? _closing;
  List<_Row> _rows = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Yon nouvo tranzaksyon chanje lavant yo; yon desizyon chanje estati a.
    _live = Realtime.instance.listen(const {'transactions', 'cash'}, () => _load(keepInputs: true));
  }

  @override
  void dispose() {
    _live?.cancel();
    _note.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load({String? date, bool keepInputs = false}) async {
    try {
      final exp = await CashApi.instance.expected(date: date ?? _date);
      if (!mounted) return;
      final previous = {for (final r in _rows) r.currency: r};
      final closing = exp.closing;
      final byCur = {for (final l in closing?.lines ?? const <CashLine>[]) l.currency: l};
      final currencies = {...exp.currencies.map((c) => c.currency), ...byCur.keys}.toList()..sort();
      final rows = <_Row>[];
      for (final cur in currencies) {
        final c = exp.currencies.where((x) => x.currency == cur).firstOrNull;
        final saved = byCur[cur];
        final old = keepInputs ? previous[cur] : null;
        final row = _Row(
          cur,
          opening: saved?.opening ?? c?.suggestedOpening ?? 0,
          deposit: saved?.deposit ?? 0,
          counted: saved?.counted,
          sales: c?.sales ?? 0,
          txCount: c?.txCount ?? 0,
          pendingCount: c?.pendingCount ?? 0,
          refundedCount: c?.refundedCount ?? 0,
        );
        if (old != null) {
          // Ajan an t ap tape: pa efase sa l te antre.
          row.opening.text = old.opening.text;
          row.deposit.text = old.deposit.text;
          row.counted.text = old.counted.text;
        }
        rows.add(row);
      }
      for (final r in _rows) {
        r.dispose();
      }
      setState(() {
        _date = exp.date;
        _today = exp.today;
        _closing = closing;
        _rows = rows;
        _loading = false;
        _error = null;
        if (!keepInputs) _note.text = closing?.note ?? '';
      });
    } on ApiException catch (err) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = err.message;
        });
      }
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickDate() async {
    final today = _today;
    if (today == null) return;
    final t = DateTime.parse(today);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date ?? today),
      firstDate: t.subtract(const Duration(days: 60)),
      lastDate: t,
      helpText: 'Ki jou pou fèmen?',
    );
    if (picked == null) return;
    setState(() => _loading = true);
    await _load(date: picked.toIso8601String().substring(0, 10));
  }

  void _addCurrency() async {
    final have = _rows.map((r) => r.currency).toSet();
    final options = _extraCurrencies.where((c) => !have.contains(c)).toList();
    if (options.isEmpty) return;
    final cur = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Ajoute yon deviz nan kès la', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final c in options) ListTile(title: Text(c), onTap: () => Navigator.pop(context, c)),
        ]),
      ),
    );
    if (cur == null) return;
    setState(() => _rows = [..._rows, _Row(cur)]..sort((a, b) => a.currency.compareTo(b.currency)));
  }

  bool get _locked => _closing?.isValidated ?? false;
  bool get _hasVariance => _rows.any((r) => r.hasCount && r.variance.abs() >= 0.005);

  Future<void> _submit() async {
    final missing = _rows.where((r) => !r.hasCount).map((r) => r.currency).toList();
    if (_rows.isEmpty) return _toast('Pa gen anyen pou fèmen: ajoute yon deviz.');
    if (missing.isNotEmpty) return _toast('Antre kach ou konte an ${missing.join(', ')}.');
    if (_hasVariance && _note.text.trim().length < 5) {
      return _toast('Gen yon ekar: eksplike l nan nòt la (omwen 5 karaktè).');
    }
    setState(() => _saving = true);
    try {
      final closing = await CashApi.instance.submit(
        date: _date!,
        note: _note.text.trim(),
        lines: [
          for (final r in _rows)
            {
              'currency': r.currency,
              'opening': _num(r.opening.text),
              'deposit': _num(r.deposit.text),
              'counted': _num(r.counted.text)
            },
        ],
      );
      if (!mounted) return;
      setState(() => _closing = closing);
      _toast(
          closing.balanced ? 'Kès la balanse. Fèmti a voye.' : 'Fèmti a voye ak yon ekar. Administratè a ap gade l.');
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DashboardPanel(
          child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    }
    if (_error != null) {
      return DashboardPanel(child: Text(_error!, style: const TextStyle(color: _crit)));
    }
    final closing = _closing;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            _date == _today ? 'Jodi a · ${_day(_date ?? '')}' : _day(_date ?? ''),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DashboardColors.ink),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: const Text('Chanje jou'),
        ),
      ]),
      const SizedBox(height: 12),
      if (closing != null) ...[_StatusBanner(closing: closing), const SizedBox(height: 12)],
      if (_rows.isEmpty)
        const DashboardPanel(
          child: Text('Pa gen lavant jou sa a. Ajoute yon deviz si ou gen kach nan kès la.',
              style: TextStyle(color: DashboardColors.muted)),
        ),
      for (final r in _rows) ...[
        _CurrencyCard(row: r, locked: _locked, onChanged: () => setState(() {})),
        const SizedBox(height: 12)
      ],
      if (!_locked) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: _addCurrency, icon: const Icon(Icons.add), label: const Text('Ajoute yon deviz')),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('cash-note'),
          controller: _note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _hasVariance ? 'Poukisa gen ekar? (obligatwa)' : 'Nòt (opsyonèl)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.lock_clock_outlined),
          label: Text(closing == null ? 'Voye fèmti kès la' : 'Voye fèmti a ankò'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ],
    ]);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.closing});

  final CashClosing closing;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, text) = switch (closing.status) {
      'validated' => (
          _okBg,
          _ok,
          Icons.verified_outlined,
          'Valide pa ${closing.decidedByName.isEmpty ? 'administratè a' : closing.decidedByName}. Jounen sa a fèmen.'
        ),
      'rejected' => (_critBg, _crit, Icons.undo, 'Rejte: ${closing.decisionNote}. Korije epi voye l ankò.'),
      _ => (_warnBg, _warn, Icons.hourglass_top, 'Voye. L ap tann validasyon administratè a.'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: DashboardColors.ink))),
      ]),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({required this.row, required this.locked, required this.onChanged});

  final _Row row;
  final bool locked;
  final VoidCallback onChanged;

  Widget _field(String label, TextEditingController c, {String? helper, Key? key}) => TextField(
        key: key,
        controller: c,
        enabled: !locked,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          suffixText: row.currency,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cur = row.currency;
    final v = row.variance;
    return DashboardPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: DashboardColors.brand, borderRadius: BorderRadius.circular(6)),
            child:
                Text(cur, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${row.txCount} tranzaksyon'
              '${row.pendingCount > 0 ? ' · ${row.pendingCount} poko livre' : ''}'
              '${row.refundedCount > 0 ? ' · ${row.refundedCount} echwe (pa konte)' : ''}',
              style: const TextStyle(color: DashboardColors.muted, fontSize: 12.5),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > 560;
          final opening = _field('Fon kès (maten)', row.opening, key: ValueKey('opening-$cur'));
          final deposit = _field('Depo bay pwopriyetè a', row.deposit,
              helper: 'Kach ou remèt jodi a', key: ValueKey('deposit-$cur'));
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: opening),
                  const SizedBox(width: 12),
                  Expanded(child: deposit),
                ])
              : Column(children: [opening, const SizedBox(height: 12), deposit]);
        }),
        const SizedBox(height: 14),
        _Line(label: 'Lavant kach (sistèm nan)', value: '+${fmtMoney(row.sales)} $cur'),
        _Line(label: 'Kès atann', value: '${fmtMoney(row.expected)} $cur', bold: true),
        const SizedBox(height: 10),
        _field('Kach ou konte', row.counted, key: ValueKey('counted-$cur')),
        const SizedBox(height: 10),
        if (row.hasCount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: v.abs() < 0.005 ? _okBg : (v < 0 ? _critBg : _warnBg),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(v.abs() < 0.005 ? Icons.check_circle : Icons.error_outline,
                  color: _varColor(v.abs() < 0.005 ? 0 : v), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v.abs() < 0.005
                      ? 'Kès la balanse'
                      : (v < 0 ? 'Manke ${fmtMoney(-v)} $cur' : 'An plis ${fmtMoney(v)} $cur'),
                  style: TextStyle(fontWeight: FontWeight.w900, color: _varColor(v.abs() < 0.005 ? 0 : v)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
      color: DashboardColors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}

// ============================================================ owner / admin

class _ClosingsView extends StatefulWidget {
  const _ClosingsView();

  @override
  State<_ClosingsView> createState() => _ClosingsViewState();
}

class _ClosingsViewState extends State<_ClosingsView> {
  int _days = 1;
  String _status = '';
  String? _today;
  CashClosingList? _data;
  String? _error;
  String? _busy;
  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    _live = Realtime.instance.listen(const {'cash', 'transactions'}, _load);
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Jodi a selon sèvè a (lè Ayiti), pa selon revèy aparèy la.
      _today ??= (await CashApi.instance.expected()).today;
      final data = await CashApi.instance.list(from: _isoShift(_today!, 1 - _days), to: _today!, status: _status);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = err.message);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _decide(CashClosing c, bool validate) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(validate ? 'Valide kès ${c.staffName}?' : 'Rejte fèmti a?'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(validate
                  ? 'Jounen ${_day(c.date)} ap fèmen: ajan an p ap ka chanje l ankò.'
                  : 'Ajan an ap resevwa rezon an epi l ap refè fèmti a.'),
              if (!c.balanced && c.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Nòt ajan an: ${c.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: !validate,
                decoration: InputDecoration(
                  labelText: validate ? 'Nòt (opsyonèl)' : 'Sa pou l korije (obligatwa)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anile')),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(validate ? 'Valide' : 'Rejte'),
              ),
            ],
          ),
        ) ??
        false;
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (!ok) return;
    setState(() => _busy = c.closingId);
    try {
      if (validate) {
        await CashApi.instance.validate(c.closingId, note: note);
        _toast('Kès ${c.staffName} valide.');
      } else {
        await CashApi.instance.reject(c.closingId, note: note);
        _toast('Fèmti a voye tounen bay ${c.staffName}.');
      }
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busy = null);
      _load();
    }
  }

  Future<void> _export() async {
    final data = _data;
    if (data == null || data.closings.isEmpty) return _toast('Pa gen fèmti pou ekspòte.');
    String cell(Object? v) {
      final s = '${v ?? ''}';
      return RegExp(r'[",;\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final rows = <String>[
      'Dat,Ajan,Deviz,Fon kès,Lavant,Tranzaksyon,Depo,Kès atann,Kach konte,Ekar,Estati,Nòt ajan,Valide pa,Nòt validasyon'
    ];
    for (final c in data.closings) {
      for (final l in c.lines) {
        rows.add([
          c.date,
          c.staffName,
          l.currency,
          l.opening.toStringAsFixed(2),
          l.sales.toStringAsFixed(2),
          l.txCount,
          l.deposit.toStringAsFixed(2),
          l.expected.toStringAsFixed(2),
          l.counted.toStringAsFixed(2),
          l.variance.toStringAsFixed(2),
          c.status,
          c.note,
          c.decidedByName,
          c.decisionNote,
        ].map(cell).join(','));
      }
    }
    final name = 'femti-kes-${_isoShift(_today!, 1 - _days)}-$_today.csv';
    // BOM: Excel li aksan kreyòl yo kòrèkteman.
    final bytes = utf8.encode('﻿${rows.join('\n')}\n');
    try {
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
        fileNameOverrides: [name],
        text: 'Fèmti kès VOUPVAPCASH',
      ));
      if (result.status == ShareResultStatus.unavailable) _toast('Fichye CSV la telechaje.');
    } catch (err) {
      _toast('Ekspòtasyon an pa mache: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final me = AuthRepositoryProvider.instance.currentUser?.uid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('Jodi a')),
            ButtonSegment(value: 7, label: Text('7 jou')),
            ButtonSegment(value: 30, label: Text('30 jou')),
          ],
          selected: {_days},
          onSelectionChanged: (s) {
            setState(() => _days = s.first);
            _load();
          },
        ),
        for (final (value, label) in const [
          ('', 'Tout'),
          ('submitted', 'An atant'),
          ('validated', 'Valide'),
          ('rejected', 'Rejte')
        ])
          ChoiceChip(
            label: Text(label),
            selected: _status == value,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _status = value);
              _load();
            },
          ),
        OutlinedButton.icon(
            onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Ekspòte CSV')),
      ]),
      const SizedBox(height: 16),
      if (_error != null) DashboardPanel(child: Text(_error!, style: const TextStyle(color: _crit))),
      if (data == null && _error == null)
        const DashboardPanel(
            child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
      if (data != null) ...[
        _Summary(data: data),
        const SizedBox(height: 16),
        if (data.closings.isEmpty)
          const DashboardPanel(
              child: Text('Pa gen fèmti kès sou peryòd sa a.', style: TextStyle(color: DashboardColors.muted))),
        for (final c in data.closings) ...[
          _ClosingCard(
            closing: c,
            busy: _busy == c.closingId,
            canDecide: c.isSubmitted && c.staffUid != me,
            onValidate: () => _decide(c, true),
            onReject: () => _decide(c, false),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final CashClosingList data;

  @override
  Widget build(BuildContext context) {
    final variances = data.variance.entries.where((e) => e.value.abs() >= 0.005).toList();
    Widget tile(String label, String value, Color color, {String? foot}) => Expanded(
          child: DashboardPanel(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(color: DashboardColors.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              if (foot != null) Text(foot, style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        tile('Pou valide', '${data.pending}', data.pending > 0 ? _warn : DashboardColors.ink),
        const SizedBox(width: 12),
        tile(
          'Ekar sou peryòd la',
          variances.isEmpty ? 'Okenn' : variances.map((e) => _signed(e.value, e.key)).join('  '),
          variances.isEmpty ? _ok : (variances.any((e) => e.value < 0) ? _crit : _warn),
        ),
      ]),
      if (data.missingToday.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _warnBg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.schedule, color: _warn, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Poko fèmen kès jodi a: ${data.missingToday.join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: DashboardColors.ink)),
            ),
          ]),
        ),
      ],
    ]);
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({
    required this.closing,
    required this.busy,
    required this.canDecide,
    required this.onValidate,
    required this.onReject,
  });

  final CashClosing closing;
  final bool busy;
  final bool canDecide;
  final VoidCallback onValidate;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = closing;
    final (label, fg, bg) = switch (c.status) {
      'validated' => ('Valide', _ok, _okBg),
      'rejected' => ('Rejte', _crit, _critBg),
      _ => ('An atant', _warn, _warnBg),
    };
    return DashboardPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('${c.staffName.isEmpty ? '—' : c.staffName} · ${_day(c.date)}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final l in c.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 48, child: Text(l.currency, style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(
                child: Text('atann ${fmtMoney(l.expected)} · konte ${fmtMoney(l.counted)}',
                    style: const TextStyle(color: DashboardColors.muted, fontSize: 13)),
              ),
              Text(
                l.variance.abs() < 0.005 ? 'balanse' : _signed(l.variance, l.currency),
                style:
                    TextStyle(fontWeight: FontWeight.w900, color: _varColor(l.variance.abs() < 0.005 ? 0 : l.variance)),
              ),
            ]),
          ),
        if (c.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Nòt ajan an: ${c.note}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        ],
        if (c.decisionNote.isNotEmpty || (c.isValidated && c.decidedByName.isNotEmpty))
          Text(
            '${c.isValidated ? 'Valide' : 'Rejte'} pa ${c.decidedByName}${c.decisionNote.isEmpty ? '' : ': ${c.decisionNote}'}',
            style: const TextStyle(fontSize: 12.5, color: DashboardColors.muted),
          ),
        if (canDecide) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              onPressed: busy ? null : onValidate,
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Valide'),
            ),
            OutlinedButton(onPressed: busy ? null : onReject, child: const Text('Rejte')),
          ]),
        ],
      ]),
    );
  }
}
