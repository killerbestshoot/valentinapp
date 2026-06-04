class ServiceModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final String enterpriseId;

  ServiceModel({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.icon = '',
    this.enterpriseId = '',
  });

  factory ServiceModel.fromMap(Map<String, dynamic> data, String id) {
    return ServiceModel(
      id: id,
      name: (data['name'] ?? data['title'] ?? 'Unknown Service').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      icon: (data['icon'] ?? '').toString(),
      enterpriseId: (data['enterpriseId'] ?? '').toString(),
    );
  }
}
