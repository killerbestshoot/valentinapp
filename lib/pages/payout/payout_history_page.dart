import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PayoutHistoryPage extends StatefulWidget {
  const PayoutHistoryPage({super.key});

  @override
  State<PayoutHistoryPage> createState() => _PayoutHistoryPageState();
}

class _PayoutHistoryPageState extends State<PayoutHistoryPage> {
  String selectedStatus = 'all';

  Future<Map<String, String>> getCurrentUserMeta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) {
      throw Exception('User profile not found');
    }

    return {
      'uid': user.uid,
      'role': (data['role'] ?? 'unknown').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> buildStream({
    required String uid,
    required String role,
    required String enterpriseId,
  }) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('payout_requests');

    final isOwnerOrAdmin = role == 'owner' || role == 'administrator';

    if (isOwnerOrAdmin) {
      query = query.where('enterpriseId', isEqualTo: enterpriseId);
    } else {
      query = query.where('uid', isEqualTo: uid);
    }

    if (selectedStatus != 'all') {
      query = query.where('status', isEqualTo: selectedStatus);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  String formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget buildStatusChip(String status) {
    return Chip(
      label: Text(status),
      backgroundColor: statusColor(status).withValues(alpha: 0.15),
      side: BorderSide(color: statusColor(status)),
      labelStyle: TextStyle(
        color: statusColor(status),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget buildFilters() {
    final options = ['all', 'pending', 'approved', 'rejected'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        children: options.map((status) {
          final selected = selectedStatus == status;
          return ChoiceChip(
            label: Text(status),
            selected: selected,
            onSelected: (_) {
              setState(() {
                selectedStatus = status;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget buildPayoutCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final amount = (data['amount'] ?? 0).toString();
    final currency = (data['currency'] ?? 'USD').toString();
    final status = (data['status'] ?? 'pending').toString();
    final enterpriseId = (data['enterpriseId'] ?? '').toString();
    final serviceName = (data['serviceName'] ?? '').toString();
    final createdAt = formatTimestamp(data['createdAt']);
    final approvedAt = formatTimestamp(data['approvedAt']);
    final rejectedAt = formatTimestamp(data['rejectedAt']);
    final approvedBy = (data['approvedBy'] ?? '').toString();
    final rejectedBy = (data['rejectedBy'] ?? '').toString();
    final approvedByRole = (data['approvedByRole'] ?? '').toString();
    final rejectedByRole = (data['rejectedByRole'] ?? '').toString();
    final balanceBefore = (data['balanceBefore'] ?? '').toString();
    final balanceAfter = (data['balanceAfter'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$amount $currency',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Enterprise: $enterpriseId'),
            Text('Service: $serviceName'),
            Text('Created: $createdAt'),
            if (status == 'approved') ...[
              const SizedBox(height: 8),
              Text('Approved at: $approvedAt'),
              Text('Approved by: $approvedBy'),
              Text('Approver role: $approvedByRole'),
              Text('Balance before: $balanceBefore'),
              Text('Balance after: $balanceAfter'),
            ],
            if (status == 'rejected') ...[
              const SizedBox(height: 8),
              Text('Rejected at: $rejectedAt'),
              Text('Rejected by: $rejectedBy'),
              Text('Rejector role: $rejectedByRole'),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildBody(Map<String, String> meta) {
    final uid = meta['uid'] ?? '';
    final role = meta['role'] ?? '';
    final enterpriseId = meta['enterpriseId'] ?? '';

    if (enterpriseId.isEmpty) {
      return const Center(
        child: Text('No enterprise assigned to this user'),
      );
    }

    return Column(
      children: [
        buildFilters(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: buildStream(
              uid: uid,
              role: role,
              enterpriseId: enterpriseId,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No payout history found'),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) => buildPayoutCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout History'),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: getCurrentUserMeta(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return buildBody(snapshot.data ?? {});
        },
      ),
    );
  }
}
