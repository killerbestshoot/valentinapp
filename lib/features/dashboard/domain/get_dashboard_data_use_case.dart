import '../data/firestore_dashboard_repository.dart';
import '../domain/dashboard_repository.dart';
import '../models/dashboard_data.dart';

class GetDashboardDataUseCase {
  GetDashboardDataUseCase({DashboardRepository? repository})
      : _repository = repository ?? FirestoreDashboardRepository.instance;

  final DashboardRepository _repository;

  Future<DashboardData> execute() => _repository.loadDashboardData();
}
