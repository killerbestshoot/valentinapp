import '../models/app_role.dart';
import '../session/app_session.dart';
import 'app_permission.dart';

class PermissionService {
  static bool can(AppPermission permission) {
    final role = AppSession.currentRole;

    switch (role) {
      case AppRole.owner:
        return true;

      case AppRole.admin:
        return {
          AppPermission.viewDashboard,
          AppPermission.viewTransactions,
          AppPermission.editTransaction,
          AppPermission.viewReports,
          AppPermission.viewClients,
          AppPermission.manageSettings,
          AppPermission.manageTeam,
        }.contains(permission);

      case AppRole.agent:
        return {
          AppPermission.viewDashboard,
          AppPermission.createTransaction,
          AppPermission.viewTransactions,
          AppPermission.editTransaction,
          AppPermission.viewReports,
          AppPermission.viewClients,
          AppPermission.manageSettings,
        }.contains(permission);

      case AppRole.client:
        return {
          AppPermission.viewDashboard,
          AppPermission.viewClientPortal,
          AppPermission.manageSettings,
        }.contains(permission);
    }
  }
}
