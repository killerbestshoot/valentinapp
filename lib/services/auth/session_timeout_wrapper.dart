import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;

  const SessionTimeoutWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper> {
  Timer? _timer;

  void _restartTimer() {
    _timer?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _timer = Timer(const Duration(minutes: 2), () async {
      await FirebaseAuth.instance.signOut();
    });
  }

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartTimer(),
      onPointerMove: (_) => _restartTimer(),
      onPointerSignal: (_) => _restartTimer(),
      child: widget.child,
    );
  }
}
