import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../shared/presentation/pages/access_denied_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can(AppPermission.viewReports)) {
      return const AccessDeniedPage(
        message: 'Wl sa pa gen aks ak rap yo.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rap V6'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Er rap'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();
          final weekStart = _startOfWeek(now);

          int totalCount = docs.length;
          double totalAmount = 0;
          int todayCount = 0;
          double todayAmount = 0;
          int weekCount = 0;
          double weekAmount = 0;
          int monthCount = 0;
          double monthAmount = 0;

          final Set<String> uniqueClients = {};

          for (final doc in docs) {
            final data = doc.data();
            final amount = _toDouble(data['amount']);
            final phone = (data['phone'] ?? '').toString().trim();
            final createdAt = data['createdAt'];

            if (phone.isNotEmpty) {
              uniqueClients.add(phone);
            }

            totalAmount += amount;

            if (createdAt is Timestamp) {
              final date = createdAt.toDate();

              if (_isSameDay(date, now)) {
                todayCount++;
                todayAmount += amount;
              }

              if (!date.isBefore(weekStart)) {
                weekCount++;
                weekAmount += amount;
              }

              if (date.year == now.year && date.month == now.month) {
                monthCount++;
                monthAmount += amount;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statCard(
                title: 'Total tranzaksyon',
                value: totalCount.toString(),
                icon: Icons.receipt_long,
              ),
              const SizedBox(height: 12),
              _statCard(
                title: 'Total montan',
                value: '${totalAmount.toStringAsFixed(2)} HTG',
                icon: Icons.payments,
              ),
              const SizedBox(height: 12),
              _statCard(
                title: 'Jodi a',
                value: '$todayCount | ${todayAmount.toStringAsFixed(2)} HTG',
                icon: Icons.today,
              ),
              const SizedBox(height: 12),
              _statCard(
                title: 'Semn sa',
                value: '$weekCount | ${weekAmount.toStringAsFixed(2)} HTG',
                icon: Icons.calendar_view_week,
              ),
              const SizedBox(height: 12),
              _statCard(
                title: 'Mwa sa',
                value: '$monthCount | ${monthAmount.toStringAsFixed(2)} HTG',
                icon: Icons.calendar_month,
              ),
              const SizedBox(height: 12),
              _statCard(
                title: 'Kliyan aktif',
                value: uniqueClients.length.toString(),
                icon: Icons.people,
              ),
            ],
          );
        },
      ),
    );
  }
}
