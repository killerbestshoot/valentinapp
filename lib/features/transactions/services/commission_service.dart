class CommissionService {
  static Map<String, double> calculate(double amount) {
    double ownerPercent = 40;
    double adminPercent = 20;
    double agentPercent = 40;

    double owner = amount * ownerPercent / 100;
    double admin = amount * adminPercent / 100;
    double agent = amount * agentPercent / 100;

    return {"owner": owner, "admin": admin, "agent": agent};
  }
}
