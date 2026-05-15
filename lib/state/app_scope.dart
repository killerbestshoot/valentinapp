import 'package:flutter/material.dart';
import 'app_state.dart';

class AppScope extends InheritedWidget {
  final AppState appState;

  const AppScope({
    super.key,
    required this.appState,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final AppScope? result =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(result != null, 'No AppScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return oldWidget.appState != appState;
  }
}
