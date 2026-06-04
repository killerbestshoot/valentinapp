import '../models/service_model.dart';

abstract class ServiceRepository {
  Future<List<ServiceModel>> loadServices();
}
