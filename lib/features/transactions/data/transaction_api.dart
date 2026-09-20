import '../../../core/network/api_client.dart';

/// Yon tranzaksyon, jan serveur SQLite la voye l.
///
/// Non chan yo se menm ak sa Firestore te genyen, pou ekran ki egziste yo pa
/// bezwen reekri tout lojik lekti yo.
class TransactionRecord {
  const TransactionRecord({
    required this.txId,
    required this.serviceName,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.currency,
    required this.status,
    this.senderFee = 0,
    this.staffName = '',
    this.staffUid = '',
    this.enterpriseName = '',
    this.gatewayRef = '',
    this.note = '',
    this.createdAt,
  });

  final String txId;
  final String serviceName;
  final String customerName;
  final String customerPhone;
  /// Sa benefisyè a resevwa.
  final double amount;
  final String currency;
  final String status;

  /// Frè ANVWAYÈ a peye anplis (0 = san frè).
  ///
  /// Se pa frè pasrèl la: sa a se yon depans antrepriz la, kliyan an pa wè l.
  final double senderFee;

  bool get hasSenderFee => senderFee > 0;

  /// Sa anvwayè a soti nan pòch li an tou.
  double get totalPaid => amount + senderFee;
  final String staffName;
  final String staffUid;
  final String enterpriseName;
  final String gatewayRef;
  final String note;
  final DateTime? createdAt;

  bool get isDelivered => status == 'delivered';
  bool get isPending => status == 'pending' || status == 'sending';

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];

    return TransactionRecord(
      txId: '${json['txId'] ?? ''}',
      serviceName: '${json['serviceName'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      customerPhone: '${json['customerPhone'] ?? ''}',
      amount: json['paymentAmount'] is num
          ? (json['paymentAmount'] as num).toDouble()
          : 0,
      currency: '${json['paymentCurrency'] ?? 'USD'}',
      status: '${json['status'] ?? 'pending'}',
      senderFee:
          json['senderFee'] is num ? (json['senderFee'] as num).toDouble() : 0,
      staffName: '${json['staffName'] ?? ''}',
      staffUid: '${json['staffUid'] ?? ''}',
      enterpriseName: '${json['enterpriseName'] ?? ''}',
      gatewayRef: '${json['gatewayRef'] ?? ''}',
      note: '${json['note'] ?? ''}',
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }
}

/// Konvèsyon an, jan serveur a kalkile l lè transfè a te fèt.
///
/// Pa gen frè pasrèl isit la: resi a montre frè ANVWAYÈ a peye
/// ([TransactionRecord.senderFee]), ki se yon lòt bagay nèt.
///
/// Yo pa soti nan tab to jounen an: yo fikse sou liy transfè a. Konsa yon resi
/// ki enprime jodi a bay menm chif yo nan yon mwa, menm si to a bouje.
class DeliveryDetails {
  const DeliveryDetails({
    required this.amountHtg,
    required this.rateToHtg,
    required this.rateCurrency,
    this.network = '',
  });

  /// Sa benefisyè a resevwa nan men l, an gouden.
  final double amountHtg;

  /// Konbyen gouden 1 [rateCurrency] te vo lè transfè a fèt.
  final double rateToHtg;
  final String rateCurrency;

  final String network;

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : 0;

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      amountHtg: _toDouble(json['amountHtg']),
      rateToHtg: _toDouble(json['rateToHtg']),
      rateCurrency: '${json['rateCurrency'] ?? ''}',
      network: '${json['network'] ?? ''}',
    );
  }
}

/// Estatistik sou TOUT antrepriz la.
class TransactionStats {
  const TransactionStats({
    required this.total,
    required this.pending,
    required this.delivered,
    required this.failed,
    required this.volumes,
  });

  final int total;
  final int pending;
  final int delivered;
  final int failed;

  /// Volim pa deviz. Nou pa adisyone deviz diferan ansanm.
  final Map<String, double> volumes;

  static const empty = TransactionStats(
    total: 0,
    pending: 0,
    delivered: 0,
    failed: 0,
    volumes: {},
  );

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  /// Deviz ki pi gwo a — sa ki parèt an gwo sou kat la.
  String get primaryVolume {
    if (volumes.isEmpty) return '0';

    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return '${_format(entries.first.value)} ${entries.first.key}';
  }

  /// Rès deviz yo — liy anba a.
  String get secondaryVolume {
    if (volumes.length < 2) return '';

    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.skip(1).map((e) => '${_format(e.value)} ${e.key}').join(' + ');
  }

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['volumes'] as Map?) ?? const {};
    final volumes = <String, double>{};

    raw.forEach((key, value) {
      if (value is num) volumes['$key'] = value.toDouble();
    });

    int count(String key) => json[key] is num ? (json[key] as num).toInt() : 0;

    return TransactionStats(
      total: count('total'),
      pending: count('pending'),
      delivered: count('delivered'),
      failed: count('failed'),
      volumes: volumes,
    );
  }
}

/// Aksè tranzaksyon yo sou serveur SQLite la (ranplase `collection('transactions')`).
class TransactionApi {
  TransactionApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static TransactionApi? _instance;

  static TransactionApi get instance => _instance ??= TransactionApi();

  /// Pou tès yo.
  static void override(TransactionApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<TransactionRecord>> list({int limit = 25, String? status}) async {
    final json = await _client.get('/api/transactions', query: {
      'limit': limit,
      if (status != null && status.isNotEmpty) 'status': status,
    });

    final items = (json['transactions'] as List?) ?? const [];
    return items
        .map((item) => TransactionRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Yon sèl tranzaksyon. Voye `null` si li pa egziste (oswa si li nan yon
  /// lòt antrepriz — serveur a pa fè diferans lan espre).
  Future<TransactionRecord?> find(String txId) async {
    try {
      final json = await _client.get('/api/transactions/$txId');
      return TransactionRecord.fromJson(
        json['transaction'] as Map<String, dynamic>,
      );
    } on ApiException catch (err) {
      if (err.code == 'not_found' || err.status == 404) return null;
      rethrow;
    }
  }

  /// Tranzaksyon an ak chif livrezon li yo, pou resi a.
  ///
  /// `delivery` vid pou yon tranzaksyon san transfè Bazik (rechaj minit,
  /// livrezon deklare alamen): resi a annik sote liy sa yo.
  Future<({TransactionRecord record, DeliveryDetails? delivery})?> findWithDelivery(
    String txId,
  ) async {
    try {
      final json = await _client.get('/api/transactions/$txId');
      final delivery = json['delivery'];

      return (
        record: TransactionRecord.fromJson(
          json['transaction'] as Map<String, dynamic>,
        ),
        delivery: delivery is Map<String, dynamic>
            ? DeliveryDetails.fromJson(delivery)
            : null,
      );
    } on ApiException catch (err) {
      if (err.code == 'not_found' || err.status == 404) return null;
      rethrow;
    }
  }

  Future<TransactionStats> stats() async {
    final json = await _client.get('/api/transactions/stats');
    return TransactionStats.fromJson(json['stats'] as Map<String, dynamic>);
  }

  Future<TransactionRecord> create({
    required String serviceName,
    required String customerName,
    required String customerPhone,
    required double amount,
    required String currency,
    double senderFee = 0,
    String country = '',
    String note = '',
  }) async {
    final json = await _client.post('/api/transactions', {
      'serviceName': serviceName,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'paymentAmount': amount,
      'paymentCurrency': currency,
      if (senderFee > 0) 'senderFee': senderFee,
      if (country.isNotEmpty) 'country': country,
      if (note.isNotEmpty) 'note': note,
    });

    return TransactionRecord.fromJson(json['transaction'] as Map<String, dynamic>);
  }

  Future<TransactionRecord> updateStatus(String txId, String status) async {
    final json = await _client.patch('/api/transactions/$txId', {'status': status});
    return TransactionRecord.fromJson(json['transaction'] as Map<String, dynamic>);
  }

  Future<void> remove(String txId) async {
    await _client.delete('/api/transactions/$txId');
  }
}
