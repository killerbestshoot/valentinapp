import '../../../core/config/app_environment.dart';
import '../domain/dashboard_repository.dart';
import 'firestore_dashboard_repository.dart';
import 'mock_dashboard_repository.dart';

class DashboardRepositoryProvider {
  DashboardRepositoryProvider._();

  static DashboardRepository get instance {
    if (AppEnvironment.mockFirebase) {
      return MockDashboardRepository.instance;
    }
    return FirestoreDashboardRepository.instance;
  }
}
