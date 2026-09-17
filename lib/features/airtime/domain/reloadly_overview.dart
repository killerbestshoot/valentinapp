/// Vi administratè sou kont Reloadly a (onglet "Sante sistèm").
///
/// Chak pèmisyon jeton an bay yon seksyon. Seksyon lajan yo (sòld, komisyon,
/// istorik) rive ak `restricted: true` lè moun k ap gade a pa owner: se
/// serveur a ki filtre yo, UI a montre sèlman poukisa yo pa la.
library;

double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class ReloadlyPermission {
  const ReloadlyPermission({
    required this.scope,
    required this.label,
    required this.granted,
    required this.ownerOnly,
  });

  final String scope;
  final String label;
  final bool granted;
  final bool ownerOnly;

  factory ReloadlyPermission.fromJson(Map<String, dynamic> json) => ReloadlyPermission(
        scope: '${json['scope'] ?? ''}',
        label: '${json['label'] ?? json['scope'] ?? ''}',
        granted: json['granted'] == true,
        ownerOnly: json['ownerOnly'] == true,
      );
}

/// Yon seksyon: swa done yo, swa rezon ki fè yo pa la.
class ReloadlySection<T> {
  const ReloadlySection({required this.ok, this.restricted = false, this.error = '', this.data});

  final bool ok;

  /// `true` = rezève pou owner (serveur a pa menm rele Reloadly).
  final bool restricted;

  /// `missing_scope` = pèmisyon an pa bay sou kont lan.
  final String error;
  final T? data;

  bool get missingScope => error == 'missing_scope';

  static ReloadlySection<T> parse<T>(
    dynamic raw,
    T Function(dynamic data) map,
  ) {
    final json = (raw as Map?)?.cast<String, dynamic>() ?? const {};
    if (json['ok'] == true) return ReloadlySection<T>(ok: true, data: map(json['data']));

    return ReloadlySection<T>(
      ok: false,
      restricted: json['restricted'] == true,
      error: '${json['error'] ?? ''}',
    );
  }
}

class ReloadlyOperatorRow {
  const ReloadlyOperatorRow({
    required this.operatorId,
    required this.name,
    required this.kind,
    required this.status,
    required this.denominationType,
    required this.senderCurrency,
    required this.minAmount,
    required this.maxAmount,
    required this.fxRate,
    required this.supportsLocalAmounts,
  });

  final int operatorId;
  final String name;

  /// 'airtime' | 'bundle' | 'data' | 'pin' — se sèlman `airtime` nou vann.
  final String kind;
  final String status;
  final String denominationType;
  final String senderCurrency;
  final double minAmount;
  final double maxAmount;
  final double fxRate;
  final bool supportsLocalAmounts;

  bool get sellable => kind == 'airtime' && status == 'ACTIVE';

  factory ReloadlyOperatorRow.fromJson(Map<String, dynamic> json) => ReloadlyOperatorRow(
        operatorId: _toDouble(json['operatorId']).round(),
        name: '${json['name'] ?? ''}',
        kind: '${json['kind'] ?? 'airtime'}',
        status: '${json['status'] ?? ''}',
        denominationType: '${json['denominationType'] ?? ''}',
        senderCurrency: '${json['senderCurrency'] ?? ''}',
        minAmount: _toDouble(json['minAmount']),
        maxAmount: _toDouble(json['maxAmount']),
        fxRate: _toDouble(json['fxRate']),
        supportsLocalAmounts: json['supportsLocalAmounts'] == true,
      );
}

class ReloadlyBalance {
  const ReloadlyBalance({
    required this.balance,
    required this.currency,
    required this.lowBalanceThreshold,
    required this.updatedAt,
  });

  final double balance;
  final String currency;

  /// Papòt alèt regle sou dashboard Reloadly a (0 = pa regle).
  final double lowBalanceThreshold;
  final String updatedAt;

  bool get low => lowBalanceThreshold > 0 && balance <= lowBalanceThreshold;

  factory ReloadlyBalance.fromJson(Map<String, dynamic> json) => ReloadlyBalance(
        balance: _toDouble(json['balance']),
        currency: '${json['currency'] ?? ''}',
        lowBalanceThreshold: _toDouble(json['lowBalanceThreshold']),
        updatedAt: '${json['updatedAt'] ?? ''}',
      );
}

class ReloadlyCommission {
  const ReloadlyCommission({
    required this.operatorName,
    required this.percentage,
    required this.localPercentage,
    required this.updatedAt,
  });

  final String operatorName;

  /// Remiz Reloadly: TOUT maj antrepriz la sou yon rechaj.
  final double percentage;
  final double localPercentage;
  final String updatedAt;

  factory ReloadlyCommission.fromJson(Map<String, dynamic> json) => ReloadlyCommission(
        operatorName: '${json['operatorName'] ?? ''}',
        percentage: _toDouble(json['percentage']),
        localPercentage: _toDouble(json['localPercentage']),
        updatedAt: '${json['updatedAt'] ?? ''}',
      );
}

class ReloadlyTopupRow {
  const ReloadlyTopupRow({
    required this.transactionId,
    required this.status,
    required this.operatorName,
    required this.requestedAmount,
    required this.requestedCurrency,
    required this.deliveredAmount,
    required this.deliveredCurrency,
    required this.discount,
    required this.date,
  });

  final String transactionId;
  final String status;
  final String operatorName;
  final double requestedAmount;
  final String requestedCurrency;
  final double deliveredAmount;
  final String deliveredCurrency;
  final double discount;
  final String date;

  factory ReloadlyTopupRow.fromJson(Map<String, dynamic> json) => ReloadlyTopupRow(
        transactionId: '${json['transactionId'] ?? ''}',
        status: '${json['status'] ?? ''}',
        operatorName: '${json['operatorName'] ?? ''}',
        requestedAmount: _toDouble(json['requestedAmount']),
        requestedCurrency: '${json['requestedCurrency'] ?? ''}',
        deliveredAmount: _toDouble(json['deliveredAmount']),
        deliveredCurrency: '${json['deliveredCurrency'] ?? ''}',
        discount: _toDouble(json['discount']),
        date: '${json['date'] ?? ''}',
      );
}

class ReloadlyOverview {
  const ReloadlyOverview({
    required this.enabled,
    required this.mode,
    required this.permissions,
    required this.operators,
    required this.promotions,
    required this.balance,
    required this.commissions,
    required this.history,
    this.warning = '',
  });

  final bool enabled;
  final String mode;
  final String warning;
  final List<ReloadlyPermission> permissions;

  final ReloadlySection<List<ReloadlyOperatorRow>> operators;
  final ReloadlySection<List<Map<String, dynamic>>> promotions;
  final ReloadlySection<ReloadlyBalance> balance;
  final ReloadlySection<List<ReloadlyCommission>> commissions;
  final ReloadlySection<List<ReloadlyTopupRow>> history;

  /// `true` lè seksyon lajan yo rezève (moun nan se pa owner).
  bool get moneyRestricted => balance.restricted;

  static List<Map<String, dynamic>> _maps(dynamic data) =>
      ((data as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  factory ReloadlyOverview.fromJson(Map<String, dynamic> json) {
    final sections = (json['sections'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ReloadlyOverview(
      enabled: json['enabled'] != false,
      mode: '${json['mode'] ?? ''}',
      warning: '${json['warning'] ?? ''}',
      permissions: ((json['permissions'] as List?) ?? const [])
          .map((e) => ReloadlyPermission.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      operators: ReloadlySection.parse(
        sections['operators'],
        (data) => _maps(data).map(ReloadlyOperatorRow.fromJson).toList(),
      ),
      promotions: ReloadlySection.parse(sections['promotions'], _maps),
      balance: ReloadlySection.parse(
        sections['balance'],
        (data) => ReloadlyBalance.fromJson((data as Map).cast<String, dynamic>()),
      ),
      commissions: ReloadlySection.parse(
        sections['commissions'],
        (data) => _maps(data).map(ReloadlyCommission.fromJson).toList(),
      ),
      history: ReloadlySection.parse(
        sections['history'],
        (data) => _maps(data).map(ReloadlyTopupRow.fromJson).toList(),
      ),
    );
  }
}
