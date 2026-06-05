import 'package:flutter/material.dart';
import 'package:mon_premye_app/pages/transactions/create_transaction_page.dart';

class DynamicTransactionPage extends StatelessWidget {
  final String? serviceId;
  final Map<String, dynamic>? serviceData;

  const DynamicTransactionPage({
    super.key,
    this.serviceId,
    this.serviceData,
  });

  @override
  Widget build(BuildContext context) {
    return const CreateTransactionPage();
  }
}
