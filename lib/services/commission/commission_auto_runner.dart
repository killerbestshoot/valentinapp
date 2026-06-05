import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_premye_app/services/commission/commission_service.dart';

class CommissionAutoRunner extends StatefulWidget {
  final Widget child;
  const CommissionAutoRunner({super.key, required this.child});

  @override
  State<CommissionAutoRunner> createState() => _CommissionAutoRunnerState();
}

class _CommissionAutoRunnerState extends State<CommissionAutoRunner> {
  Timer? timer;

  Future<void> runNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await CommissionService.runForEnterprise('ENT-001');
  }

  @override
  void initState() {
    super.initState();
    runNow();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => runNow());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
