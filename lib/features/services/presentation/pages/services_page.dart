import 'package:flutter/material.dart';

import '../../domain/get_services_use_case.dart';
import '../../models/service_model.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final GetServicesUseCase _servicesUseCase = GetServicesUseCase();
  late final Future<List<ServiceModel>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _servicesUseCase.execute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: FutureBuilder<List<ServiceModel>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Unable to load services: ${snapshot.error}'),
              ),
            );
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return const Center(
              child: Text('Pa gen sèvis disponib pou kounye a.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text(service.description.isNotEmpty
                      ? service.description
                      : 'Kategori: ${service.category.isNotEmpty ? service.category : 'N/A'}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
