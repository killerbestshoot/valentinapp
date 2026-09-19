import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pwa_installer.dart';

/// Ti kat ki pwopoze pou enstale app la sou ekran dakèy la.
///
/// Li parèt sèlman sou web, lè navigatè a di nou li ka enstale app la, epi li
/// disparèt pou tout tan si moun nan di non. Ajan yo louvri app la plizyè fwa
/// pa jou: yon rakousi sou ekran dakèy la sove yo anpil tan, men yon bandwòl
/// ki tounen chak fwa ta anmède yo.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key, required this.child, this.installer});

  final Widget child;

  /// Pou tès yo; pa defo se navigatè a ki reponn.
  final PwaInstaller? installer;

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  static const _dismissedKey = 'voupvapcash.pwa.dismissed';

  late final PwaInstaller _installer;
  late final bool _ownsInstaller;

  bool _dismissed = true; // nou kache l jiskaske nou li repons ki sove a

  @override
  void initState() {
    super.initState();

    _ownsInstaller = widget.installer == null;
    _installer = widget.installer ?? createPwaInstaller();
    _installer.start();

    _loadDismissed();
  }

  @override
  void dispose() {
    if (_ownsInstaller) _installer.dispose();
    super.dispose();
  }

  Future<void> _loadDismissed() async {
    var dismissed = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = prefs.getBool(_dismissedKey) ?? false;
    } catch (_) {
      // Stokaj bloke: nou pwopoze, se pi piti mal la.
    }

    if (!mounted) return;
    setState(() => _dismissed = dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
    } catch (_) {
      // Li p ap sonje, men li pa parèt ankò nan sesyon sa a.
    }
  }

  Future<void> _install() async {
    final accepted = await _installer.promptInstall();
    if (accepted) await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<PwaInstallMode>(
          valueListenable: _installer.mode,
          builder: (context, mode, _) {
            if (_dismissed || mode == PwaInstallMode.none) {
              return const SizedBox.shrink();
            }

            return _Card(
              manual: mode == PwaInstallMode.manual,
              onDismiss: _dismiss,
              onInstall: _install,
            );
          },
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.manual,
    required this.onDismiss,
    required this.onInstall,
  });

  final bool manual;
  final VoidCallback onDismiss;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: colors.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.install_mobile, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Enstale VOUPVAPCASH',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      manual
                          ? 'Nan Safari: peze bouton Pataje a, epi chwazi '
                              '« Sou ekran dakèy ».'
                          : 'Li louvri tankou yon app, li pi rapid, epi li rete '
                              'sou ekran dakèy ou.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onDismiss,
                          child: Text(manual ? 'Konprann' : 'Pita'),
                        ),
                        if (!manual) ...[
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: onInstall,
                            child: const Text('Enstale'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
