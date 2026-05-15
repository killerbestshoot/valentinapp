import 'package:flutter/material.dart';

class AgentDashboardPage extends StatelessWidget {
  const AgentDashboardPage({super.key});

  Widget cardBlock(String title, String subtitle, String buttonText) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3AA7A3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76B9D1),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget settingsBlock() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RGLAGES',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Text('Solde', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              _Badge(text: '242.99 mxn', color: Color(0xFF169C9A)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text('Topup', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              _Badge(text: '53 mxn', color: Colors.grey),
              SizedBox(width: 10),
              _Badge(text: '1.06 %', color: Color(0xFF61B7D7)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text('Com', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              _Badge(text: '0.00 mxn', color: Color(0xFF6CC06C)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE1E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2CB7B7),
        elevation: 0,
        title: const Text('Agent Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            settingsBlock(),
            cardBlock('Cashwallet', 'Dpt Mon Cash & Nat Cash', 'Envoyez'),
            cardBlock('TOPUP', 'Envoyez des minutes sur un tlphone', 'Envoyez'),
            cardBlock('PAPPADAP', 'Rechargez un marchand de papadap', 'Rechargez'),
            cardBlock('SOLDE', 'Dposez des fonds sur votre compte', 'Visa & mastercard'),
            cardBlock('BALANCE', 'Rechargez votre balance topup', 'Rechargez'),
            cardBlock('TRANSACTIONS', 'Retrouvez toutes vos fiches, reus et rapports', 'Recherchez'),
            cardBlock('Paramtres', 'Mettez votre profil et mot-de-passe  jour', 'Modifiez'),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
}

