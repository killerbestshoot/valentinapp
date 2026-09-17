import 'package:mon_premye_app/core/config/app_environment.dart';

import '../domain/airtime_gateway.dart';
import 'fake_airtime_gateway.dart';
import 'http_airtime_gateway.dart';

/// Chwazi ki pasrèl Minit Haiti UI a itilize (menm modèl ak
/// `PaymentGatewayProvider`).
class AirtimeGatewayProvider {
  AirtimeGatewayProvider._();

  static AirtimeGateway? _instance;

  static AirtimeGateway get instance {
    return _instance ??= AppEnvironment.mockFirebase
        ? FakeAirtimeGateway()
        : HttpAirtimeGateway();
  }

  /// Pou tès yo.
  static void override(AirtimeGateway gateway) => _instance = gateway;

  static void reset() => _instance = null;
}
