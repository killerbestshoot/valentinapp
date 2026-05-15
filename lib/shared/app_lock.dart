import 'dart:async';
import 'package:flutter/material.dart';

class AppLock extends StatefulWidget {
  final Widget child;
  final Duration idleTimeout;
  final VoidCallback onLock;

  const AppLock({
    super.key,
    required this.child,
    required this.onLock,
    this.idleTimeout = const Duration(minutes: 1),
  });

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.onLock();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.idleTimeout, widget.onLock);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
