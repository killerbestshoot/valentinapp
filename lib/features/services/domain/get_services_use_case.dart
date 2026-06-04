import '../data/firestore_service_repository.dart';
import '../domain/service_repository.dart';
import '../models/service_model.dart';

class GetServicesUseCase {
  GetServicesUseCase({ServiceRepository? repository})
      : _repository = repository ?? FirestoreServiceRepository.instance;

  final ServiceRepository _repository;

  Future<List<ServiceModel>> execute() => _repository.loadServices();
}
