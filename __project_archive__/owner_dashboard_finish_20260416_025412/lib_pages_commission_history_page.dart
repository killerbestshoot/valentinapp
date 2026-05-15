import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";

class CommissionHistoryPage extends StatefulWidget {
  const CommissionHistoryPage({super.key});

  @override
  State<CommissionHistoryPage> createState() => _CommissionHistoryPageState();
}

class _CommissionHistoryPageState extends State<CommissionHistoryPage> {
  String _sourceFilter = "all";
  String _dateFilter = "all";
  String _searchTxId = "";

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat("yyyy-MM-dd HH:mm").format(value.toDate());
    }
    return "-";
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse("$v") ?? 0;
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String currentValue,
    required String chipValue,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    final selected = currentValue == chipValue;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(chipValue),
    );
  }

  bool _matchDateFilter(DateTime? dt) {
    if (_dateFilter == "all") return true;
    if (dt == null) return false;

    final now = DateTime.now();

    if (_dateFilter == "today") {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }

    if (_dateFilter == "7d") {
      return dt.isAfter(now.subtract(const Duration(days: 7)));
    }

    if (_dateFilter == "30d") {
      return dt.isAfter(now.subtract(const Duration(days: 30)));
    }

    return true;
  }

  Future<void> _copyTxId(String txId) async {
    await Clipboard.setData(ClipboardData(text: txId));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("TX ID copied: $txId")),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection("payout_logs")
        .where("type", isEqualTo: "commission_applied");

    if (_sourceFilter != "all") {
      query = query.where("source", isEqualTo: _sourceFilter);
    }

    final stream = query.orderBy("createdAt", descending: true).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Commission History"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text("Erè: ${snap.error}"),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snap.data?.docs ?? [];

          final docs = allDocs.where((d) {
            final data = d.data();
            final txId = (data["txId"] ?? "").toString().toLowerCase();
            final q = _searchTxId.trim().toLowerCase();
            final createdAt = _toDate(data["createdAt"]);

            final txMatch = q.isEmpty ? true : txId.contains(q);
            final dateMatch = _matchDateFilter(createdAt);

            return txMatch && dateMatch;
          }).toList();

          double totalAgent = 0;
          double totalOwner = 0;
          double totalAll = 0;

          for (final d in docs) {
            final data = d.data();
            totalAgent += _asDouble(data["agentCommission"]);
            totalOwner += _asDouble(data["ownerCommission"]);
            totalAll += _asDouble(data["amount"]);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "FILTER BY SOURCE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(
                    currentValue: _sourceFilter,
                    chipValue: "all",
                    label: "All",
                    onChanged: (v) => setState(() => _sourceFilter = v),
                  ),
                  _filterChip(
                    currentValue: _sourceFilter,
                    chipValue: "manual",
                    label: "Manual",
                    onChanged: (v) => setState(() => _sourceFilter = v),
                  ),
                  _filterChip(
                    currentValue: _sourceFilter,
                    chipValue: "weekly_scheduler",
                    label: "Weekly",
                    onChanged: (v) => setState(() => _sourceFilter = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "FILTER BY DATE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(
                    currentValue: _dateFilter,
                    chipValue: "all",
                    label: "All Time",
                    onChanged: (v) => setState(() => _dateFilter = v),
                  ),
                  _filterChip(
                    currentValue: _dateFilter,
                    chipValue: "today",
                    label: "Today",
                    onChanged: (v) => setState(() => _dateFilter = v),
                  ),
                  _filterChip(
                    currentValue: _dateFilter,
                    chipValue: "7d",
                    label: "7 Days",
                    onChanged: (v) => setState(() => _dateFilter = v),
                  ),
                  _filterChip(
                    currentValue: _dateFilter,
                    chipValue: "30d",
                    label: "30 Days",
                    onChanged: (v) => setState(() => _dateFilter = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() {
                    _searchTxId = v;
                  });
                },
                decoration: InputDecoration(
                  labelText: "Search by TX ID",
                  hintText: "Antre txId la",
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchTxId.isEmpty
                      ? const Icon(Icons.search)
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchTxId = "";
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _summaryCard(
                title: "Total Logs",
                value: "${docs.length}",
                icon: Icons.receipt_long_outlined,
              ),
              _summaryCard(
                title: "Total Agent Commission",
                value: totalAgent.toStringAsFixed(2),
                icon: Icons.person_outline,
              ),
              _summaryCard(
                title: "Total Owner Commission",
                value: totalOwner.toStringAsFixed(2),
                icon: Icons.admin_panel_settings_outlined,
              ),
              _summaryCard(
                title: "Total Commission",
                value: totalAll.toStringAsFixed(2),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Text("Pa gen commission log pou filter/search sa a."),
                  ),
                ),
              ...docs.map((d) {
                final data = d.data();

                final txId = data["txId"] ?? "-";
                final source = data["source"] ?? "-";
                final serviceName = data["serviceName"] ?? "-";
                final enterpriseId = data["enterpriseId"] ?? "-";
                final uid = data["uid"] ?? "-";
                final currency = data["currency"] ?? "USD";

                final agentCommission = _asDouble(data["agentCommission"]);
                final ownerCommission = _asDouble(data["ownerCommission"]);
                final total = _asDouble(data["amount"]);

                final createdAt = _fmtDate(data["createdAt"]);

                final balanceBefore = Map<String, dynamic>.from(
                  (data["balanceBefore"] as Map?)?.cast<String, dynamic>() ??
                      <String, dynamic>{},
                );

                final balanceAfter = Map<String, dynamic>.from(
                  (data["balanceAfter"] as Map?)?.cast<String, dynamic>() ??
                      <String, dynamic>{},
                );

                final agentBefore = _asDouble(balanceBefore["agent"]);
                final ownerBefore = _asDouble(balanceBefore["owner"]);
                final agentAfter = _asDouble(balanceAfter["agent"]);
                final ownerAfter = _asDouble(balanceAfter["owner"]);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "TX: $txId",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: "Copy TX ID",
                                onPressed: () => _copyTxId("$txId"),
                                icon: const Icon(Icons.copy_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Date: $createdAt"),
                          Text("Source: $source"),
                          Text("Service: $serviceName"),
                          Text("Enterprise: $enterpriseId"),
                          Text("Staff UID: $uid"),
                          const Divider(height: 24),
                          Text(
                            "Agent Commission: ${agentCommission.toStringAsFixed(2)} $currency",
                          ),
                          Text(
                            "Owner Commission: ${ownerCommission.toStringAsFixed(2)} $currency",
                          ),
                          Text(
                            "Total: ${total.toStringAsFixed(2)} $currency",
                          ),
                          const Divider(height: 24),
                          Text(
                            "Agent Balance: ${agentBefore.toStringAsFixed(2)} -> ${agentAfter.toStringAsFixed(2)}",
                          ),
                          Text(
                            "Owner Balance: ${ownerBefore.toStringAsFixed(2)} -> ${ownerAfter.toStringAsFixed(2)}",
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
