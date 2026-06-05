import '../data/dashboard_repository_provider.dart';
import '../domain/dashboard_repository.dart';
import '../models/dashboard_data.dart';

class GetDashboardDataUseCase {
  GetDashboardDataUseCase({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepositoryProvider.instance;

  final DashboardRepository _repository;

  Future<DashboardData> execute() => _repository.loadDashboardData();
}
