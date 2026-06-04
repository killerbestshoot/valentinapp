import 'package:flutter/material.dart';

import '../../models/service_offer.dart';

class ServiceButton extends StatelessWidget {
  const ServiceButton({
    super.key,
    required this.offer,
    required this.onTap,
  });

  final ServiceOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(offer.icon),
        label: Text(offer.title),
      ),
    );
  }
}
