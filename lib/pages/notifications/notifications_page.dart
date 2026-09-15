import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Sa ki bezwen atansyon kounye a.
///
/// Notifikasyon yo DERIVE depi done yo sou serveur a (demann an atant,
/// transfè an verifikasyon, komisyon an reta). Yo pa ka tonbe an dezakò ak
/// reyalite a: yon demann trete disparèt pou kont li.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Notifikasyon',
      children: [
        const DashboardHero(
          icon: Icons.notifications_outlined,
          title: 'Notifikasyon',
          subtitle: 'Sa ki bezwen atansyon ou kounye a.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: AsyncView<List<AppNotification>>(
            load: SystemApi.instance.notifications,
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Anyen pa bezwen atansyon ou. 👍',
            builder: (context, rows, reload) => Column(
              children: [
                ...rows.map((item) {
                  final color =
                      item.isWarning ? const Color(0xFFB45309) : DashboardColors.brand;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          item.isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                          color: color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: DashboardColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item.count}',
                            style: TextStyle(fontWeight: FontWeight.w900, color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Rafrechi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
