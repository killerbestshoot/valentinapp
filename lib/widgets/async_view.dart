import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Chaje done, montre erè a ak yon bouton "Eseye ankò", oswa montre done yo.
///
/// Odit UI a te jwenn ekran ki te rete bloke sou yon spinner pou tout tan (pa
/// gen branch erè), oswa ki te montre yon tèks wouj san okenn fason pou sòti.
/// Widget sa a fè twa eta yo — chaje, erè, done — toujou menm jan.
///
/// `load` rele yon SÈL fwa pa rechajman, pa sou chak `build`: se sa ki
/// anpeche rekèt la relanse lè klavye a louvri oswa ekran an vire.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'Pa gen anyen pou montre.',
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  /// Rechaje done yo. Piblik pou paj paran an ka rele l apre yon aksyon.
  void reload() {
    if (!mounted) return;
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          final error = snap.error;
          return _ErrorState(
            message: error is ApiException ? error.message : '$error',
            onRetry: reload,
          );
        }

        final data = snap.data as T;

        if (widget.isEmpty?.call(data) ?? false) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                widget.emptyMessage,
                style: const TextStyle(color: DashboardColors.muted),
              ),
            ),
          );
        }

        return widget.builder(context, data, reload);
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFFB91C1C)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Eseye ankò'),
          ),
        ],
      ),
    );
  }
}
