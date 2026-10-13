import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_version.dart';
import 'app_update.dart';

/// Gad vèsyon an: lè sèvè a di app la twò ansyen, ekran "Mete ajou" a ranplase
/// TOUT app la. Pa gen bouton pou fèmen l — se sèl nouvo vèsyon an ki debloke.
class UpdateGate extends StatelessWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: AppUpdate.instance.required,
      builder: (context, info, _) => info == null ? child : UpdateRequiredScreen(info: info),
    );
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.info});

  final UpdateInfo info;

  static const _brand = Color(0xFF123D2B);

  Future<void> _act(BuildContext context) async {
    final ok = kIsWeb
        // Navigatè: nouvo vèsyon an deja sou sèvè a, yon rechajman ase.
        ? await launchUrl(Uri.base, webOnlyWindowName: '_self')
        : await launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: info.downloadUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lyen an kopye: kole l nan Chrome pou telechaje nouvo vèsyon an.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('update-required'),
        backgroundColor: const Color(0xFFF4F8F1),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.system_update_alt, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nouvo vèsyon obligatwa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _brand),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kIsWeb
                        ? 'Yon nouvo vèsyon VOUPVAPCASH disponib. Rechaje paj la pou kontinye.'
                        : 'Vèsyon app ou a ($appVersion) pa ka itilize ankò. Telechaje vèsyon '
                            '${info.latestVersion} la epi enstale l pou kontinye travay.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15.5, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _act(context),
                      icon: const Icon(kIsWeb ? Icons.refresh : Icons.download),
                      label: const Text(kIsWeb ? 'Rechaje paj la' : 'Telechaje nouvo vèsyon an'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 14),
                    SelectableText(
                      info.downloadUrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF667365)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
