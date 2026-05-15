import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mon_premye_app/data/countries.dart';

class CountriesScreen extends StatefulWidget {
  const CountriesScreen({super.key});

  @override
  State<CountriesScreen> createState() => _CountriesScreenState();
}

class _CountriesScreenState extends State<CountriesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.toLowerCase().trim();

    final items = countries.where((c) {
      final text = '${c.name} ${c.dialCode} ${c.iso}'.toLowerCase();
      return text.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Lis Peyi yo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Chche peyi / kd...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = items[i];
                return ListTile(
                  title: Text('${c.name} (${c.iso})'),
                  subtitle: Text('Kd: ${c.dialCode}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // return chosen country to previous screen
                    context.pop(c);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

