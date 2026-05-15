class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';

  static const String owner = '/owner';
  static const String admin = '/admin';
  static const String agent = '/agent';
  static const String customer = '/customer';

  static const String manageAgents = '/admin/manage-agents';
  static const String manageCustomers = '/admin/manage-customers';

  static const String transactions = '/transactions';
  static const String sendMoney = '/transactions/send';
  static const String receiveMoney = '/transactions/receive';
}
