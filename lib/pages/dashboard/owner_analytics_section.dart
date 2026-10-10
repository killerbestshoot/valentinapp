import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/analytics/data/analytics_api.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Tablo owner a: KPI, volim pa jou, solvabilite, analiz gwoupe, lè chaje,
/// rezo, alèt ak dènye tranzaksyon — tout sou menm peryòd, menm deviz.
class OwnerAnalyticsSection extends StatefulWidget {
  const OwnerAnalyticsSection({
    super.key,
    required this.isWide,
    this.onOpenReceipt,
    this.refreshEvery = const Duration(seconds: 60),
  });

  final bool isWide;
  final void Function(String txId)? onOpenReceipt;
  final Duration refreshEvery;

  @override
  State<OwnerAnalyticsSection> createState() => OwnerAnalyticsSectionState();
}

const _networkColors = {
  'moncash': Color(0xFF123D2B),
  'natcash': Color(0xFF4F9D69),
  'psl': Color(0xFFC08A2E),
  'minit': Color(0xFF6B4FA0),
  'manual': Color(0xFF8A968A),
};
const _ok = Color(0xFF15803D);
const _okBg = Color(0xFFE3F3E7);
const _warn = Color(0xFFB45309);
const _warnBg = Color(0xFFFBEFD9);
const _crit = DashboardColors.danger;
const _critBg = Color(0xFFFBE4E4);

String _group3(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 12 345,67 — menm fòma ak resi yo.
String fmtMoney(double v, {int decimals = 2}) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final s = _group3(parts[0]) + (parts.length > 1 ? ',${parts[1]}' : '');
  return neg ? '−$s' : s;
}

/// 1,2 M · 45 k · 980
String fmtCompact(double v) {
  final a = v.abs();
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (a >= 1e4) return '${(v / 1e3).toStringAsFixed(0)} k';
  return fmtMoney(v, decimals: 0);
}

String _pct(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

class OwnerAnalyticsSectionState extends State<OwnerAnalyticsSection> {
  int _days = 30;
  String _currency = 'HTG';
  AnalyticsGroupBy _groupBy = AnalyticsGroupBy.agent;
  final Set<String> _networks = {...analyticsNetworks};
  String _sortKey = 'volume';
  bool _sortAsc = false;

  OwnerAnalytics? _data;
  Object? _error;
  bool _loading = false;
  Timer? _timer;
  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();
    reload();
    // Tan reyèl: chak tranzaksyon, konfimasyon oswa komisyon rechaje tablo a.
    _live = Realtime.instance.listen(const {'transactions', 'transfers', 'wallets', 'commissions'}, reload);
    // Filè sekirite si kanal la koupe.
    _timer = Timer.periodic(widget.refreshEvery, (_) => reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await AnalyticsApi.instance.owner(
        days: _days,
        currency: _currency,
        groupBy: _groupBy,
        networks: _networks,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      _loading = false;
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Filters(
          days: _days,
          currency: _currency,
          networks: _networks,
          onDays: (v) => _set(() => _days = v),
          onCurrency: (v) => _set(() => _currency = v),
          onNetwork: (n) => _set(() {
            if (_networks.contains(n) && _networks.length > 1) {
              _networks.remove(n);
            } else {
              _networks.add(n);
            }
          }),
          generatedAt: data?.generatedAt,
        ),
        const SizedBox(height: 14),
        if (_error != null && data == null)
          DashboardPanel(
            child: Text(
              _error is ApiException ? (_error as ApiException).message : 'Nou pa ka chaje analiz la: $_error',
              style: const TextStyle(color: _crit),
            ),
          )
        else if (data == null)
          const DashboardPanel(
            child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          )
        else ...[
          _KpiGrid(data: data, isWide: widget.isWide),
          const SizedBox(height: 16),
          _pair(
            _Card(
              title: 'Volim livre pa jou',
              subtitle: '${fmtCompact(data.current.volume)} ${data.currency} sou ${data.days} jou · peze yon ba pou detay',
              child: _VolumeChart(data: data, networks: _networks),
            ),
            const _SolvencyCard(),
            flexA: 2,
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Analiz gwoupe',
            subtitle: 'Gwoupe pa ${_groupBy.label.toLowerCase()} · peze yon tit pou triye',
            trailing: SegmentedButton<AnalyticsGroupBy>(
              segments: AnalyticsGroupBy.values
                  .map((g) => ButtonSegment(value: g, label: Text(g.label)))
                  .toList(),
              selected: {_groupBy},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (v) => _set(() {
                _groupBy = v.first;
                _sortKey = _groupBy == AnalyticsGroupBy.week ? 'label' : 'volume';
                _sortAsc = false;
              }),
            ),
            child: _GroupTable(
              data: data,
              sortKey: _sortKey,
              sortAsc: _sortAsc,
              onSort: (k) => setState(() {
                if (_sortKey == k) {
                  _sortAsc = !_sortAsc;
                } else {
                  _sortKey = k;
                  _sortAsc = k == 'label';
                }
              }),
            ),
          ),
          const SizedBox(height: 16),
          _pair(
            _Card(
              title: 'Lè chaje',
              subtitle: 'Kantite tranzaksyon pa jou semèn ak pa lè (lè Ayiti)',
              child: _Heatmap(heatmap: data.heatmap),
            ),
            _Card(
              title: 'Rezo',
              subtitle: 'Pati volim nan, fyabilite ak delè livrezon',
              child: _Networks(data: data),
            ),
          ),
          const SizedBox(height: 16),
          _pair(
            _Card(title: 'Pou trete', subtitle: 'Alèt sou peryòd la', child: _Alerts(alerts: data.alerts)),
            _Card(
              title: 'Dènye tranzaksyon',
              subtitle: '8 dènye yo, tout ajan',
              child: _Recent(rows: data.recent, onOpen: widget.onOpenReceipt),
            ),
            flexB: 2,
          ),
        ],
      ],
    );
  }

  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) {
    if (!widget.isWide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexA, child: a),
        const SizedBox(width: 16),
        Expanded(flex: flexB, child: b),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre
// ---------------------------------------------------------------------------

class _Filters extends StatelessWidget {
  const _Filters({
    required this.days,
    required this.currency,
    required this.networks,
    required this.onDays,
    required this.onCurrency,
    required this.onNetwork,
    this.generatedAt,
  });

  final int days;
  final String currency;
  final Set<String> networks;
  final ValueChanged<int> onDays;
  final ValueChanged<String> onCurrency;
  final ValueChanged<String> onNetwork;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 j')),
            ButtonSegment(value: 30, label: Text('30 j')),
            ButtonSegment(value: 90, label: Text('90 j')),
          ],
          selected: {days},
          showSelectedIcon: false,
          onSelectionChanged: (v) => onDays(v.first),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'HTG', label: Text('HTG')),
            ButtonSegment(value: 'USD', label: Text('USD')),
            ButtonSegment(value: 'MXN', label: Text('MXN')),
          ],
          selected: {currency},
          showSelectedIcon: false,
          onSelectionChanged: (v) => onCurrency(v.first),
        ),
        ...analyticsNetworks.map(
          (n) => FilterChip(
            label: Text(analyticsNetworkLabels[n]!),
            avatar: CircleAvatar(backgroundColor: _networkColors[n], radius: 5),
            selected: networks.contains(n),
            showCheckmark: false,
            onSelected: (_) => onNetwork(n),
          ),
        ),
        if (generatedAt != null)
          Text(
            'Mete ajou ${two(generatedAt!.hour)}:${two(generatedAt!.minute)}',
            style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kat jenerik
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16, color: DashboardColors.ink)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI
// ---------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data, required this.isWide});

  final OwnerAnalytics data;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final c = data.current;
    final p = data.previous;
    final s = data.series;
    final cur = data.currency;

    double? ratio(double a, double b) => b == 0 ? null : (a - b) / b;
    final rates = s.map((d) => d.delivered + d.failed == 0 ? 0.0 : d.delivered / (d.delivered + d.failed)).toList();

    final tiles = [
      _KpiData('Volim livre', fmtCompact(c.volume), cur, ratio(c.volume, p.volume), s.map((d) => d.totalVolume).toList(), lead: true),
      _KpiData('Tranzaksyon', fmtMoney(c.count.toDouble(), decimals: 0), '', ratio(c.count.toDouble(), p.count.toDouble()), s.map((d) => d.count.toDouble()).toList()),
      _KpiData('Pati ou (nèt)', fmtCompact(c.ownerNet), cur, ratio(c.ownerNet, p.ownerNet), s.map((d) => d.ownerNet).toList()),
      _KpiData('To siksè', c.successRate == null ? '—' : (c.successRate! * 100).toStringAsFixed(1).replaceAll('.', ','), '%',
          c.successRate == null || p.successRate == null ? null : c.successRate! - p.successRate!, rates, points: true),
      _KpiData('Tikè mwayen', fmtMoney(c.averageTicket, decimals: 0), cur, ratio(c.averageTicket, p.averageTicket),
          s.map((d) => d.delivered == 0 ? 0.0 : d.totalVolume / d.delivered).toList()),
      _KpiData('An atant', '${c.pending}', 'tx', null, s.map((d) => d.failed.toDouble()).toList(), foot: 'echèk / jou', warn: c.pending > 0),
    ];

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1100 ? 6 : box.maxWidth >= 640 ? 3 : 2;
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: tiles.map((t) => SizedBox(width: w, child: _KpiTile(t: t, days: data.days))).toList(),
      );
    });
  }
}

class _KpiData {
  _KpiData(this.label, this.value, this.unit, this.delta, this.spark,
      {this.lead = false, this.points = false, this.foot, this.warn = false});

  final String label;
  final String value;
  final String unit;
  final double? delta;
  final List<double> spark;
  final bool lead;

  /// `delta` an pwen (to siksè), pa an %.
  final bool points;
  final String? foot;
  final bool warn;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.t, required this.days});

  final _KpiData t;
  final int days;

  @override
  Widget build(BuildContext context) {
    final fg = t.lead ? DashboardColors.surface : DashboardColors.ink;
    final sub = t.lead ? DashboardColors.surface.withValues(alpha: 0.75) : DashboardColors.muted;
    final d = t.delta;
    Widget? deltaChip;
    if (d != null) {
      final up = d >= 0;
      final text = t.points
          ? '${up ? '+' : '−'}${(d.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')} pt'
          : '${up ? '+' : '−'}${(d.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')} %';
      deltaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: t.lead ? Colors.white.withValues(alpha: 0.15) : (up ? _okBg : _critBg),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: t.lead ? fg : (up ? _ok : _crit))),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: t.lead ? DashboardColors.brand : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.lead ? DashboardColors.brand : DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.label.toUpperCase(),
              style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: sub)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: t.value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: t.warn ? _warn : fg)),
              if (t.unit.isNotEmpty)
                TextSpan(text: ' ${t.unit}', style: TextStyle(fontSize: 13, color: sub)),
            ])),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (deltaChip != null) deltaChip,
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.foot ?? 'vs $days j anvan',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(
                t.spark,
                color: t.lead ? DashboardColors.surface : (t.warn ? _warn : const Color(0xFF1F7A3A)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ti liy tandans ak yon zòn plen ak pwen final la mete aksan.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, {required this.color, this.fill = true});

  final List<double> values;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final minV = math.min(0.0, values.reduce(math.min));
    final span = (maxV - minV) == 0 ? 1.0 : maxV - minV;
    final n = values.length;
    Offset at(int i) => Offset(
          n == 1 ? size.width / 2 : 2 + i * (size.width - 4) / (n - 1),
          size.height - 3 - (values[i] - minV) / span * (size.height - 8),
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(at(n - 1).dx, size.height)
        ..lineTo(at(0).dx, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.14));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(n - 1), 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) => old.values != values || old.color != color;
}

// ---------------------------------------------------------------------------
// Volim pa jou (ba anpile pa rezo)
// ---------------------------------------------------------------------------

class _VolumeChart extends StatefulWidget {
  const _VolumeChart({required this.data, required this.networks});

  final OwnerAnalytics data;
  final Set<String> networks;

  @override
  State<_VolumeChart> createState() => _VolumeChartState();
}

class _VolumeChartState extends State<_VolumeChart> {
  int? _selected;

  static const _months = ['jan', 'fev', 'mas', 'avr', 'me', 'jen', 'jiy', 'out', 'sep', 'okt', 'nov', 'des'];

  String _label(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${int.parse(parts[2])} ${_months[int.parse(parts[1]) - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.data.series;
    final nets = analyticsNetworks.where(widget.networks.contains).toList();
    final sel = _selected != null && _selected! < series.length ? series[_selected!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: nets
              .map((n) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _networkColors[n], borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text(analyticsNetworkLabels[n]!,
                        style: const TextStyle(fontSize: 12, color: DashboardColors.muted)),
                  ]))
              .toList(),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          const height = 240.0;
          return GestureDetector(
            onTapDown: (e) => _pick(e.localPosition.dx, box.maxWidth, series.length),
            onHorizontalDragUpdate: (e) => _pick(e.localPosition.dx, box.maxWidth, series.length),
            child: MouseRegion(
              onHover: (e) => _pick(e.localPosition.dx, box.maxWidth, series.length),
              onExit: (_) => setState(() => _selected = null),
              child: CustomPaint(
                size: Size(box.maxWidth, height),
                painter: _StackedBarsPainter(
                  series: series,
                  networks: nets,
                  selected: _selected,
                  labelOf: _label,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: sel == null
              ? const SizedBox(height: 20)
              : Wrap(
                  key: ValueKey(sel.date),
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text(_label(sel.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ...nets.map((n) => Text(
                          '${analyticsNetworkLabels[n]}: ${fmtMoney(sel.volume[n] ?? 0, decimals: 0)}',
                          style: const TextStyle(fontSize: 12, color: DashboardColors.muted),
                        )),
                    Text('Total ${fmtMoney(sel.totalVolume)} ${widget.data.currency} · ${sel.count} tx',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ],
    );
  }

  void _pick(double x, double width, int n) {
    if (n == 0) return;
    const padL = _StackedBarsPainter.padL;
    final i = ((x - padL) / ((width - padL - _StackedBarsPainter.padR) / n)).floor();
    final next = i < 0 || i >= n ? null : i;
    if (next != _selected) setState(() => _selected = next);
  }
}

class _StackedBarsPainter extends CustomPainter {
  _StackedBarsPainter({required this.series, required this.networks, required this.selected, required this.labelOf});

  static const padL = 48.0;
  static const padR = 6.0;
  static const padT = 8.0;
  static const padB = 24.0;

  final List<AnalyticsDay> series;
  final List<String> networks;
  final int? selected;
  final String Function(String) labelOf;

  double _niceStep(double max) {
    final raw = max / 4;
    final p = math.pow(10, (math.log(raw <= 0 ? 1 : raw) / math.ln10).floor()).toDouble();
    final m = raw / p;
    return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p;
  }

  void _text(Canvas c, String s, Offset at, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(fontSize: 10.5, color: DashboardColors.muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right ? at.dx - tp.width : align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.length;
    if (n == 0) return;
    final totals = series.map((d) => networks.fold<double>(0, (s, k) => s + (d.volume[k] ?? 0))).toList();
    final maxV = totals.fold<double>(0, math.max);
    final step = _niceStep(maxV <= 0 ? 1 : maxV);
    final top = (maxV <= 0 ? 1 : maxV / step).ceil() * step;
    final plotH = size.height - padT - padB;
    double y(double v) => padT + plotH * (1 - v / top);

    final grid = Paint()
      ..color = DashboardColors.border
      ..strokeWidth = 1;
    for (double v = 0; v <= top + 1e-9; v += step) {
      canvas.drawLine(Offset(padL, y(v)), Offset(size.width - padR, y(v)), grid);
      _text(canvas, fmtCompact(v), Offset(padL - 8, y(v)), align: TextAlign.right);
    }

    final bw = (size.width - padL - padR) / n;
    final gap = math.min(4.0, bw * 0.25);
    final every = (n / math.max(2, ((size.width - padL) / 64).floor())).ceil();

    for (var i = 0; i < n; i++) {
      final x = padL + i * bw;
      if (selected == i) {
        canvas.drawRect(Rect.fromLTWH(x, padT, bw, plotH), Paint()..color = DashboardColors.ink.withValues(alpha: 0.05));
      }
      var acc = 0.0;
      for (final k in networks) {
        final v = series[i].volume[k] ?? 0;
        if (v <= 0) continue;
        final r = Rect.fromLTRB(x + gap / 2, y(acc + v), x + bw - gap / 2, y(acc));
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(math.min(2, bw / 4))),
          Paint()..color = _networkColors[k]!,
        );
        acc += v;
      }
      if ((n - 1 - i) % every == 0) {
        _text(canvas, labelOf(series[i].date), Offset(x + bw / 2, size.height - 9), align: TextAlign.center);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarsPainter old) =>
      old.series != series || old.selected != selected || old.networks != networks;
}

// ---------------------------------------------------------------------------
// Solvabilite (owner sèlman — serveur a voye `restricted` pou lòt yo)
// ---------------------------------------------------------------------------

class _SolvencyCard extends StatefulWidget {
  const _SolvencyCard();

  @override
  State<_SolvencyCard> createState() => _SolvencyCardState();
}

class _SolvencyCardState extends State<_SolvencyCard> {
  late final Future<SystemHealth> _future = SystemApi.instance.health();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Solvabilite',
      subtitle: 'Pwovizyon pasrèl yo kont wallet ajan yo',
      child: FutureBuilder<SystemHealth>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Text('Pa disponib kounye a.', style: TextStyle(color: DashboardColors.muted));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!.solvency;
          if (s['restricted'] == true) {
            return const Text('Owner a sèlman ka wè chif sa yo.', style: TextStyle(color: DashboardColors.muted));
          }
          final status = '${s['status'] ?? 'unknown'}';
          final ratio = s['ratio'] is num ? (s['ratio'] as num).toDouble() : null;
          double toD(dynamic v) => v is num ? v.toDouble() : 0;
          final debt = toD((s['liabilities'] as Map?)?['total']);
          final cover = toD((s['coverage'] as Map?)?['total']);
          final (label, color, bg) = switch (status) {
            'covered' => ('Kouvri', _ok, _okBg),
            'thin' => ('Jis', _warn, _warnBg),
            'uncovered' => ('Dekouvri', _crit, _critBg),
            _ => ('Enkoni', DashboardColors.muted, DashboardColors.surface),
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(ratio == null ? '—' : ratio.toStringAsFixed(2).replaceAll('.', ','),
                      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('× kouvri', style: TextStyle(color: DashboardColors.muted)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio == null ? 0 : (ratio / 2).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: DashboardColors.surface,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0×', style: TextStyle(fontSize: 10.5, color: DashboardColors.muted)),
                  Text('1× minimòm', style: TextStyle(fontSize: 10.5, color: DashboardColors.muted)),
                  Text('2×', style: TextStyle(fontSize: 10.5, color: DashboardColors.muted)),
                ],
              ),
              const SizedBox(height: 10),
              _kv('Pwovizyon (Bazik + Reloadly)', '${fmtMoney(cover)} HTG'),
              _kv('Wallet ajan yo pou kouvri', '${fmtMoney(debt)} HTG'),
              _kv('Maj', '${fmtMoney(cover - debt)} HTG', bold: true),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: DashboardColors.border))),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: DashboardColors.muted, fontSize: 13))),
            Text(v, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Tablo gwoupe
// ---------------------------------------------------------------------------

class _GroupTable extends StatelessWidget {
  const _GroupTable({required this.data, required this.sortKey, required this.sortAsc, required this.onSort});

  final OwnerAnalytics data;
  final String sortKey;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  num _value(AnalyticsGroup g, String k) => switch (k) {
        'count' => g.count,
        'volume' => g.volume,
        'share' => g.share,
        'ticket' => g.averageTicket,
        'fee' => g.fee,
        'agent' => g.agentCommission,
        'owner' => g.ownerNet,
        'success' => g.successRate ?? -1,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final rows = [...data.groups];
    rows.sort((a, b) {
      final r = sortKey == 'label' ? a.key.compareTo(b.key) : _value(a, sortKey).compareTo(_value(b, sortKey));
      return sortAsc ? r : -r;
    });
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Pa gen tranzaksyon pou filtre sa yo.', style: TextStyle(color: DashboardColors.muted))),
      );
    }
    final cur = data.currency;
    final avg = data.current.successRate;

    Widget head(String key, String label, {bool numeric = true, double w = 110}) {
      final active = sortKey == key;
      return InkWell(
        onTap: () => onSort(key),
        child: SizedBox(
          width: w,
          child: Row(
            mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: active ? DashboardColors.ink : DashboardColors.muted)),
              ),
              if (active) Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 12),
            ],
          ),
        ),
      );
    }

    Widget cell(String s, {double w = 110, bool bold = false, Color? color}) => SizedBox(
          width: w,
          child: Text(s,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color)),
        );

    final total = data.current;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            head('label', data.groups.isEmpty ? '' : 'Gwoup', numeric: false, w: 200),
            head('count', 'Tx', w: 60),
            head('volume', 'Volim $cur', w: 120),
            head('share', 'Pati', w: 140),
            head('ticket', 'Tikè mwayen'),
            head('fee', 'Frè'),
            head('agent', 'Kom. ajan'),
            head('owner', 'Pati ou'),
            head('success', 'Siksè', w: 90),
            const SizedBox(width: 100),
          ]),
          const Divider(height: 14),
          ...rows.map((g) {
            final flagged = avg != null && g.successRate != null && g.delivered + (g.count - g.delivered) >= 10 && g.successRate! < avg - 0.03;
            final rate = g.successRate;
            final (fg, bg) = rate == null
                ? (DashboardColors.muted, DashboardColors.surface)
                : flagged
                    ? (_crit, _critBg)
                    : rate >= 0.96
                        ? (_ok, _okBg)
                        : (_warn, _warnBg);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(
                  width: 200,
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _networkColors[g.key]?.withValues(alpha: 0.15) ?? DashboardColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        g.label.isEmpty ? '?' : g.label.characters.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.brand, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(g.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: DashboardColors.ink)),
                    ),
                  ]),
                ),
                cell('${g.count}', w: 60),
                cell(fmtMoney(g.volume), w: 120, bold: true),
                SizedBox(
                  width: 140,
                  child: Row(children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: g.share.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: DashboardColors.surface,
                          color: const Color(0xFF1F7A3A),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(_pct(g.share),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                    ),
                  ]),
                ),
                cell(fmtMoney(g.averageTicket)),
                cell(fmtMoney(g.fee)),
                cell(fmtMoney(g.agentCommission)),
                cell(fmtMoney(g.ownerNet), color: g.ownerNet < 0 ? _crit : null),
                SizedBox(
                  width: 90,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(_pct(rate), style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 24,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: CustomPaint(
                      painter: SparklinePainter(g.trend, color: flagged ? _crit : const Color(0xFF1F7A3A), fill: false),
                    ),
                  ),
                ),
              ]),
            );
          }),
          const Divider(height: 14, thickness: 2),
          Row(children: [
            SizedBox(width: 200, child: Text('Total · ${rows.length} gwoup', style: const TextStyle(fontWeight: FontWeight.w800))),
            cell('${total.count}', w: 60, bold: true),
            cell(fmtMoney(total.volume), w: 120, bold: true),
            const SizedBox(width: 140),
            cell(fmtMoney(total.averageTicket), bold: true),
            cell(fmtMoney(total.fee), bold: true),
            cell(fmtMoney(total.agentCommission), bold: true),
            cell(fmtMoney(total.ownerNet), bold: true),
            cell(_pct(total.successRate), w: 90, bold: true),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lè chaje
// ---------------------------------------------------------------------------

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.heatmap});

  final List<List<int>> heatmap;

  static const _days = ['Len', 'Mad', 'Mèk', 'Jed', 'Van', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    final maxV = heatmap.expand((r) => r).fold<int>(0, math.max);
    const lo = DashboardColors.soft;
    const hi = DashboardColors.brand;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 36),
            ...List.generate(
              24,
              (h) => SizedBox(
                width: 19,
                child: Text(h % 3 == 0 ? '${h}h' : '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9.5, color: DashboardColors.muted)),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ...List.generate(heatmap.length, (d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                SizedBox(
                    width: 36,
                    child: Text(_days[d], style: const TextStyle(fontSize: 10.5, color: DashboardColors.muted))),
                ...List.generate(24, (h) {
                  final v = heatmap[d].length > h ? heatmap[d][h] : 0;
                  return Tooltip(
                    message: '${_days[d]} ${h}h–${h + 1}h: $v tranzaksyon',
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: Color.lerp(lo, hi, maxV == 0 ? 0 : v / maxV),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ]),
            );
          }),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Kalm', style: TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
            const SizedBox(width: 8),
            Container(
              width: 120,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: [lo, hi]),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Chaje', style: TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rezo
// ---------------------------------------------------------------------------

class _Networks extends StatelessWidget {
  const _Networks({required this.data});

  final OwnerAnalytics data;

  @override
  Widget build(BuildContext context) {
    final rows = data.networks;
    if (rows.isEmpty) {
      return const Text('Pa gen tranzaksyon.', style: TextStyle(color: DashboardColors.muted));
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: rows
                  .where((r) => r.share > 0)
                  .map((r) => Expanded(
                        flex: math.max(1, (r.share * 1000).round()),
                        child: Container(color: _networkColors[r.network]),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(flex: 3, child: Text('REZO', style: _head)),
          Expanded(flex: 2, child: Text('VOLIM', textAlign: TextAlign.right, style: _head)),
          Expanded(flex: 2, child: Text('SIKSÈ', textAlign: TextAlign.right, style: _head)),
          Expanded(flex: 2, child: Text('DELÈ', textAlign: TextAlign.right, style: _head)),
        ]),
        ...rows.map((r) => Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: DashboardColors.border))),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: _networkColors[r.network], borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${_pct(r.share)} · ${r.count} tx',
                            style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                      ]),
                    ),
                  ]),
                ),
                Expanded(flex: 2, child: Text(fmtCompact(r.volume), textAlign: TextAlign.right)),
                Expanded(
                  flex: 2,
                  child: Text(_pct(r.successRate),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (r.successRate ?? 1) >= 0.96 ? _ok : _warn)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(r.medianSeconds == null ? '—' : '${r.medianSeconds} s', textAlign: TextAlign.right),
                ),
              ]),
            )),
      ],
    );
  }
}

const _head = TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: DashboardColors.muted);

// ---------------------------------------------------------------------------
// Alèt + dènye tranzaksyon
// ---------------------------------------------------------------------------

class _Alerts extends StatelessWidget {
  const _Alerts({required this.alerts});

  final List<AnalyticsAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.check_circle_outline, color: _ok),
          SizedBox(width: 8),
          Text('Anyen pou trete.'),
        ]),
      );
    }
    return Column(
      children: alerts.map((a) {
        final color = switch (a.level) { 'critical' => _crit, 'warning' => _warn, _ => const Color(0xFF1F7A3A) };
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DashboardColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(a.detail, style: const TextStyle(color: DashboardColors.muted, fontSize: 12.5)),
          ]),
        );
      }).toList(),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.rows, this.onOpen});

  final List<AnalyticsRecent> rows;
  final void Function(String txId)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Pa gen tranzaksyon sou peryòd la.', style: TextStyle(color: DashboardColors.muted));
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return Column(
      children: rows.map((r) {
        final (label, fg, bg) = switch (r.status) {
          'delivered' => ('Livre', _ok, _okBg),
          'failed' => ('Echwe', _crit, _critBg),
          'verifying' => ('Pou verifye', _warn, _warnBg),
          _ => ('An kou', _warn, _warnBg),
        };
        return InkWell(
          onTap: onOpen == null ? null : () => onOpen!(r.txId),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: DashboardColors.border))),
            child: Row(children: [
              SizedBox(
                width: 46,
                child: Text(r.createdAt == null ? '' : '${two(r.createdAt!.hour)}:${two(r.createdAt!.minute)}',
                    style: const TextStyle(fontSize: 12, color: DashboardColors.muted)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.staffName.isEmpty ? '—' : r.staffName,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${analyticsNetworkLabels[r.network] ?? r.network} · ${r.phone}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: DashboardColors.muted)),
                ]),
              ),
              Text('${fmtMoney(r.amount)} ${r.currency}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
