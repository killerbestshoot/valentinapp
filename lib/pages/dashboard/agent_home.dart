import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/features/analytics/data/analytics_api.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/features/wallet/presentation/widgets/exchange_rates_card.dart';
import 'package:mon_premye_app/pages/dashboard/owner_analytics_section.dart' show fmtMoney, fmtCompact;
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

const _ok = Color(0xFF15803D);
const _okBg = Color(0xFFE3F3E7);
const _warn = Color(0xFFB45309);
const _warnBg = Color(0xFFFBEFD9);
const _crit = DashboardColors.danger;
const _critBg = Color(0xFFFBE4E4);
const _accent = Color(0xFF1F7A3A);

const _serviceColors = {
  'MonCash': Color(0xFFC8102E),
  'NatCash': Color(0xFF0B5FA5),
  'Minit Haiti': Color(0xFF6B4FA0),
};

/// Akèy ajan an: wallet li, aksyon rapid, aktivite ak komisyon li, transfè an
/// kou ak tranzaksyon li yo — tout mete ajou an tan reyèl.
class AgentHome extends StatefulWidget {
  const AgentHome({
    super.key,
    required this.onCreate,
    required this.onRepeat,
    required this.onOpenReceipt,
    required this.onOpenPayout,
  });

  final VoidCallback onCreate;
  final void Function(TransactionRecord tx) onRepeat;
  final void Function(String txId) onOpenReceipt;
  final VoidCallback onOpenPayout;

  @override
  State<AgentHome> createState() => AgentHomeState();
}

class AgentHomeState extends State<AgentHome> {
  int _days = 1;
  AgentAnalytics? _data;
  Object? _error;
  List<TransactionRecord> _recent = const [];
  List<TransactionRecord> _favorites = const [];
  String _filter = '';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Timer? _fallback;
  StreamSubscription<RealtimeEvent>? _live;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    reload();
    _live = Realtime.instance.listen(
      const {'transactions', 'transfers', 'wallets', 'commissions', 'topups', 'payouts'},
      reload,
    );
    _fallback = Timer.periodic(const Duration(seconds: 90), (_) => reload());
  }

  @override
  void dispose() {
    _live?.cancel();
    _fallback?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    try {
      final results = await Future.wait([
        AnalyticsApi.instance.agent(days: _days),
        TransactionApi.instance.list(
          limit: 40,
          status: _filter.isEmpty ? null : _filter,
          search: _searchCtrl.text,
        ),
      ]);
      if (!mounted) return;
      final recent = results[1] as List<TransactionRecord>;
      setState(() {
        _data = results[0] as AgentAnalytics;
        _error = null;
        _recent = recent;
        if (_filter.isEmpty && _searchCtrl.text.trim().isEmpty) _favorites = _favoritesFrom(recent);
      });
    } catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      _loading = false;
    }
  }

  List<TransactionRecord> _favoritesFrom(List<TransactionRecord> rows) {
    final seen = <String>{};
    final out = <TransactionRecord>[];
    for (final tx in rows) {
      final key = tx.customerPhone.replaceAll(RegExp(r'\D'), '');
      if (key.isEmpty || tx.customerName.trim().isEmpty || !seen.add(key)) continue;
      out.add(tx);
      if (out.length == 6) break;
    }
    return out;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _requestTopup() async {
    final data = _data;
    final uid = AuthRepositoryProvider.instance.currentUser?.uid;
    if (data == null || uid == null) return;
    final result = await showDialog<({double amount, String note})>(
      context: context,
      builder: (_) => _TopupDialog(currency: data.walletCurrency ?? data.currency),
    );
    if (result == null) return;
    try {
      await WalletApi.instance.requestTopup(
        targetUid: uid,
        amount: result.amount,
        currency: data.walletCurrency ?? data.currency,
        note: result.note,
      );
      _toast('Demann rechaj la voye bay administratè a.');
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error is ApiException ? (_error as ApiException).message : '$_error',
                  style: const TextStyle(color: _crit),
                ),
              ),
      );
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 980;
      final left = [
        _WalletCard(data: data, onTopup: _requestTopup, onPayout: widget.onOpenPayout),
        const SizedBox(height: 14),
        _CreateButton(onTap: widget.onCreate),
        if (_favorites.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Voye ankò',
            subtitle: 'Dènye benefisyè ou yo, an yon klik',
            child: SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _Favorite(tx: _favorites[i], onTap: () => widget.onRepeat(_favorites[i])),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Panel(
          title: 'Aktivite ou',
          subtitle: _days == 1 ? 'Depi 00:00 jodi a' : '$_days dènye jou yo',
          trailing: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Jodi a')),
              ButtonSegment(value: 7, label: Text('7 j')),
              ButtonSegment(value: 30, label: Text('30 j')),
            ],
            selected: {_days},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (v) {
              setState(() => _days = v.first);
              reload();
            },
          ),
          child: _Stats(data: data),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Komisyon ou',
          subtitle: '7 dènye jou · ${data.currency}',
          child: _CommissionChart(data: data),
        ),
      ];
      final right = [
        _Panel(
          title: 'An kou',
          subtitle: 'Transfè ki poko fini — mete ajou an dirèk',
          child: _InProgress(rows: data.inProgress),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Tranzaksyon mwen yo',
          subtitle: 'Peze youn pou wè ak pataje resi a',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), reload);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Chèche pa non, nimewo oswa referans',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Efase rechèch la',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            reload();
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const {
                  '': 'Tout',
                  'pending': 'An atant',
                  'sending': 'Ap voye',
                  'delivered': 'Livre',
                  'failed': 'Echwe',
                }.entries.map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _filter == e.key,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _filter = e.key);
                        reload();
                      },
                    )).toList(),
              ),
              const SizedBox(height: 6),
              _TxList(rows: _recent.take(12).toList(), onOpen: widget.onOpenReceipt),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const ExchangeRatesCard(),
      ];

      return ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 32),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                const SizedBox(width: 18),
                Expanded(flex: 11, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
              ],
            )
          else ...[
            ...left,
            const SizedBox(height: 14),
            ...right,
          ],
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.data, required this.onTopup, required this.onPayout});

  final AgentAnalytics data;
  final VoidCallback onTopup;
  final VoidCallback onPayout;

  @override
  Widget build(BuildContext context) {
    final balance = data.walletBalance ?? 0;
    final cur = data.walletCurrency ?? data.currency;
    final htg = data.walletBalanceHtg ?? balance;
    // ~ yon transfè mwayen: si sòld la pa kouvri 2, ajan an dwe mande rechaj.
    final ticket = data.averageTicketHtg > 0 ? data.averageTicketHtg : 10000;
    final low = htg < ticket * 2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: DashboardColors.brand, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SÒLD DISPONIB',
              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: fmtMoney(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              TextSpan(text: ' $cur', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ])),
          ),
          if (cur != 'HTG')
            Text('≈ ${fmtMoney(htg, decimals: 0)} HTG', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          if (low) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Sòld ou ba. Mande yon rechaj anvan lè chaje yo.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onTopup,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Mande rechaj'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPayout,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.north_east, size: 18),
                label: const Text('Mande payout'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nouvo tranzaksyon', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text('MonCash · NatCash · Minit Haiti', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.arrow_forward, color: Colors.white, size: 26),
          ]),
        ),
      ),
    );
  }
}

class _Favorite extends StatelessWidget {
  const _Favorite({required this.tx, required this.onTap});

  final TransactionRecord tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _serviceColors[tx.serviceName] ?? DashboardColors.brand;
    final initials = tx.customerName
        .trim()
        .split(RegExp(r'[\s-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: DashboardColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color,
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.customerName.trim(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text('${tx.serviceName} · ${fmtMoney(tx.amount, decimals: 0)} ${tx.currency}',
                    style: const TextStyle(fontSize: 11, color: DashboardColors.muted)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});

  final AgentAnalytics data;

  @override
  Widget build(BuildContext context) {
    final cur = data.currency;
    final tiles = [
      ('Tranzaksyon', '${data.count}', '', '${data.delivered} livre', false),
      ('Volim voye', fmtCompact(data.volumeHtg), 'HTG', 'sa benefisyè yo resevwa', false),
      ('Komisyon', '+${fmtMoney(data.commissionEarned)}', cur,
          data.commissionPending > 0 ? '+${fmtMoney(data.commissionPending)} an atant' : 'tout touche', true),
      ('To siksè', data.successRate == null ? '—' : (data.successRate! * 100).toStringAsFixed(0), '%',
          '${data.failed} echèk', false),
      ('Tikè mwayen', fmtCompact(data.averageTicketHtg), 'HTG', 'pa tranzaksyon', false),
      ('Frè touche', fmtMoney(data.fee), cur, 'kliyan yo peye', false),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 520 ? 3 : 2;
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tiles
            .map((t) => Container(
                  width: w,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(color: DashboardColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.$1, style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: t.$2,
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: t.$5 ? _ok : DashboardColors.ink)),
                        if (t.$3.isNotEmpty)
                          TextSpan(text: ' ${t.$3}', style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                      ])),
                    ),
                    Text(t.$4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                  ]),
                ))
            .toList(),
      );
    });
  }
}

class _CommissionChart extends StatelessWidget {
  const _CommissionChart({required this.data});

  final AgentAnalytics data;

  @override
  Widget build(BuildContext context) {
    final total = data.commissionSeries.fold<double>(0, (s, d) => s + d.earned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(painter: _CommissionPainter(data.commissionSeries)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, children: [
          _legend(_accent, 'Touche (livre)'),
          _legend(_accent.withValues(alpha: 0.3), 'An atant'),
          Text('Total 7 jou: ${fmtMoney(total)} ${data.currency}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: DashboardColors.muted)),
      ]);
}

class _CommissionPainter extends CustomPainter {
  _CommissionPainter(this.series);

  final List<({String date, double earned, double pending, int count})> series;
  static const _days = ['Len', 'Mad', 'Mèk', 'Jed', 'Van', 'Sam', 'Dim'];

  void _text(Canvas c, String s, Offset center, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: 10.5, color: DashboardColors.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    const top = 16.0, bottom = 20.0;
    final maxV = series.map((d) => d.earned + d.pending).fold<double>(0, math.max);
    final scale = maxV <= 0 ? 0.0 : (size.height - top - bottom) / maxV;
    final bw = size.width / series.length;
    for (var i = 0; i < series.length; i++) {
      final d = series[i];
      final x = i * bw + bw * 0.18;
      final w = bw * 0.64;
      final base = size.height - bottom;
      final earnedTop = base - d.earned * scale;
      final pendingTop = earnedTop - d.pending * scale;
      if (d.earned > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x, earnedTop, x + w, base), const Radius.circular(5)),
          Paint()..color = i == series.length - 1 ? DashboardColors.brand : _accent,
        );
      }
      if (d.pending > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x, pendingTop, x + w, earnedTop), const Radius.circular(5)),
          Paint()..color = _accent.withValues(alpha: 0.3),
        );
      }
      if (d.earned > 0) _text(canvas, fmtCompact(d.earned), Offset(x + w / 2, pendingTop - 8));
      final date = DateTime.tryParse(d.date);
      final label = i == series.length - 1 ? 'Jodi a' : (date == null ? '' : _days[date.weekday - 1]);
      _text(canvas, label, Offset(x + w / 2, size.height - 8), bold: i == series.length - 1);
    }
    canvas.drawLine(
      Offset(0, size.height - bottom),
      Offset(size.width, size.height - bottom),
      Paint()
        ..color = DashboardColors.border
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CommissionPainter old) => old.series != series;
}

class _InProgress extends StatelessWidget {
  const _InProgress({required this.rows});

  final List<AgentInProgress> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(Icons.check_circle_outline, color: _ok),
          SizedBox(width: 8),
          Text('Pa gen anyen an kou.'),
        ]),
      );
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return Column(
      children: rows.map((t) {
        final verifying = t.status == 'verifying';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: DashboardColors.surface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.clientName.isEmpty ? '—' : t.clientName} · ${fmtMoney(t.amount)} ${t.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${t.service} · ${t.createdAt == null ? '' : '${two(t.createdAt!.hour)}:${two(t.createdAt!.minute)}'} · '
                  '${t.manualReview ? 'Owner a ap verifye l ak Bazik' : verifying ? 'Pasrèl la poko reponn: pa voye l ankò' : 'N ap tann konfimasyon pasrèl la'}',
                  style: const TextStyle(fontSize: 12, color: DashboardColors.muted),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _warnBg, borderRadius: BorderRadius.circular(999)),
              child: Text(verifying ? 'Pou verifye' : 'Ap voye',
                  style: const TextStyle(color: _warn, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList({required this.rows, required this.onOpen});

  final List<TransactionRecord> rows;
  final void Function(String txId) onOpen;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('Okenn tranzaksyon pa koresponn.', style: TextStyle(color: DashboardColors.muted)),
      );
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return Column(
      children: rows.map((tx) {
        final (label, fg, bg) = switch (tx.status) {
          'delivered' => ('Livre', _ok, _okBg),
          'failed' || 'canceled' => ('Echwe', _crit, _critBg),
          _ => ('An kou', _warn, _warnBg),
        };
        final color = _serviceColors[tx.serviceName] ?? DashboardColors.brand;
        final at = tx.createdAt?.toLocal();
        return InkWell(
          onTap: () => onOpen(tx.txId),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: DashboardColors.border))),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text(tx.serviceName.isEmpty ? '?' : tx.serviceName[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx.customerName.isEmpty ? '—' : tx.customerName,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${tx.serviceName}${at == null ? '' : ' · ${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}'}',
                    style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${fmtMoney(tx.amount)} ${tx.currency}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _TopupDialog extends StatefulWidget {
  const _TopupDialog({required this.currency});

  final String currency;

  @override
  State<_TopupDialog> createState() => _TopupDialogState();
}

class _TopupDialogState extends State<_TopupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mande yon rechaj'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Montan', suffixText: widget.currency),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.').trim());
                return n == null || n <= 0 ? 'Antre yon montan pi gran pase 0.' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Nòt (opsyonèl)', hintText: 'Egz. Depo kach 10/10'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anile')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              amount: double.parse(_amountCtrl.text.replaceAll(',', '.').trim()),
              note: _noteCtrl.text.trim(),
            ));
          },
          child: const Text('Voye demann lan'),
        ),
      ],
    );
  }
}
