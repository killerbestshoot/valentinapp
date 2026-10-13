import 'package:mon_premye_app/core/network/api_client.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : 0;

/// Lavant kach yon deviz pou yon jou (sèvè a kalkile l).
class CashCurrency {
  const CashCurrency({
    required this.currency,
    this.sales = 0,
    this.txCount = 0,
    this.pendingCount = 0,
    this.refundedCount = 0,
    this.suggestedOpening = 0,
  });

  final String currency;
  final double sales;
  final int txCount;

  /// Tranzaksyon ki konte nan lavant men ki poko livre.
  final int pendingCount;

  /// Tranzaksyon echwe: kliyan an te ranbouse, yo pa nan kès la.
  final int refundedCount;

  /// Kach ki te konte nan dènye fèmti a.
  final double suggestedOpening;

  factory CashCurrency.fromJson(Map<String, dynamic> j) => CashCurrency(
        currency: '${j['currency'] ?? ''}',
        sales: _d(j['sales']),
        txCount: _i(j['txCount']),
        pendingCount: _i(j['pendingCount']),
        refundedCount: _i(j['refundedCount']),
        suggestedOpening: _d(j['suggestedOpening']),
      );
}

class CashLine {
  const CashLine({
    required this.currency,
    this.opening = 0,
    this.sales = 0,
    this.txCount = 0,
    this.deposit = 0,
    this.expected = 0,
    this.counted = 0,
    this.variance = 0,
  });

  final String currency;
  final double opening;
  final double sales;
  final int txCount;
  final double deposit;
  final double expected;
  final double counted;

  /// Kach konte − kès atann. Negatif = manke, pozitif = an plis.
  final double variance;

  factory CashLine.fromJson(Map<String, dynamic> j) => CashLine(
        currency: '${j['currency'] ?? ''}',
        opening: _d(j['opening']),
        sales: _d(j['sales']),
        txCount: _i(j['txCount']),
        deposit: _d(j['deposit']),
        expected: _d(j['expected']),
        counted: _d(j['counted']),
        variance: _d(j['variance']),
      );
}

class CashClosing {
  const CashClosing({
    required this.closingId,
    required this.staffUid,
    required this.staffName,
    required this.date,
    required this.status,
    this.note = '',
    this.lines = const [],
    this.balanced = true,
    this.decidedByName = '',
    this.decisionNote = '',
  });

  final String closingId;
  final String staffUid;
  final String staffName;

  /// AAAA-MM-JJ, jou lokal Ayiti.
  final String date;

  /// `submitted`, `validated` oswa `rejected`.
  final String status;
  final String note;
  final List<CashLine> lines;
  final bool balanced;
  final String decidedByName;
  final String decisionNote;

  bool get isSubmitted => status == 'submitted';
  bool get isValidated => status == 'validated';
  bool get isRejected => status == 'rejected';

  factory CashClosing.fromJson(Map<String, dynamic> j) => CashClosing(
        closingId: '${j['closingId'] ?? ''}',
        staffUid: '${j['staffUid'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        date: '${j['date'] ?? ''}',
        status: '${j['status'] ?? 'submitted'}',
        note: '${j['note'] ?? ''}',
        lines: ((j['lines'] as List?) ?? const []).map((l) => CashLine.fromJson(l as Map<String, dynamic>)).toList(),
        balanced: j['balanced'] != false,
        decidedByName: '${j['decidedByName'] ?? ''}',
        decisionNote: '${j['decisionNote'] ?? ''}',
      );
}

class CashExpected {
  const CashExpected({required this.date, required this.today, this.currencies = const [], this.closing});

  final String date;
  final String today;
  final List<CashCurrency> currencies;
  final CashClosing? closing;
}

class CashClosingList {
  const CashClosingList({
    this.closings = const [],
    this.variance = const {},
    this.pending = 0,
    this.missingToday = const [],
  });

  final List<CashClosing> closings;

  /// Total ekar sou peryòd la, pa deviz.
  final Map<String, double> variance;

  /// Fèmti k ap tann validasyon.
  final int pending;

  /// Ajan ki gen lavant jodi a men ki poko fèmen kès yo.
  final List<String> missingToday;
}

/// Fèmti kès — `/api/cash`.
class CashApi {
  CashApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static CashApi? _instance;
  static CashApi get instance => _instance ??= CashApi();
  static void override(CashApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<CashExpected> expected({String? date, String? uid}) async {
    final j = await _client.get('/api/cash/expected', query: {
      if (date != null) 'date': date,
      if (uid != null) 'uid': uid,
    });
    return CashExpected(
      date: '${j['date'] ?? ''}',
      today: '${j['today'] ?? ''}',
      currencies: ((j['currencies'] as List?) ?? const [])
          .map((c) => CashCurrency.fromJson(c as Map<String, dynamic>))
          .toList(),
      closing: j['closing'] is Map<String, dynamic> ? CashClosing.fromJson(j['closing'] as Map<String, dynamic>) : null,
    );
  }

  /// [lines]: `{currency, opening, deposit, counted}`. Lavant yo, se sèvè a ki kalkile yo.
  Future<CashClosing> submit(
      {required String date, required List<Map<String, dynamic>> lines, String note = ''}) async {
    final j = await _client.post('/api/cash/closings', {
      'date': date,
      'lines': lines,
      if (note.isNotEmpty) 'note': note,
    });
    return CashClosing.fromJson(j['closing'] as Map<String, dynamic>);
  }

  Future<CashClosingList> list({required String from, required String to, String? status}) async {
    final j = await _client.get('/api/cash/closings', query: {
      'from': from,
      'to': to,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final variance = <String, double>{};
    (j['variance'] as Map?)?.forEach((k, v) => variance['$k'] = _d(v));
    return CashClosingList(
      closings:
          ((j['closings'] as List?) ?? const []).map((c) => CashClosing.fromJson(c as Map<String, dynamic>)).toList(),
      variance: variance,
      pending: _i(j['pending']),
      missingToday: ((j['missingToday'] as List?) ?? const [])
          .map((m) => '${(m as Map)['name'] ?? ''}')
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }

  Future<CashClosing> validate(String id, {String note = ''}) async {
    final j = await _client.post('/api/cash/closings/$id/validate', {if (note.isNotEmpty) 'note': note});
    return CashClosing.fromJson(j['closing'] as Map<String, dynamic>);
  }

  Future<CashClosing> reject(String id, {required String note}) async {
    final j = await _client.post('/api/cash/closings/$id/reject', {'note': note});
    return CashClosing.fromJson(j['closing'] as Map<String, dynamic>);
  }
}
