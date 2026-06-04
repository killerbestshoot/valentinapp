import 'package:flutter/material.dart';

import '../../../../widgets/dashboard_ui.dart';

class PapadapPage extends StatelessWidget {
  const PapadapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPage(
      title: 'Papadap',
      maxWidth: 760,
      children: [
        DashboardHero(
          icon: Icons.storefront_outlined,
          title: 'Papadap recharge',
          subtitle: 'Merchant recharge workspace.',
        ),
        SizedBox(height: 18),
        DashboardPanel(
          child: Text('Papadap service configuration is not active yet.'),
        ),
      ],
    );
  }
}
