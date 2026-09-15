import 'package:mon_premye_app/core/config/app_environment.dart';

import '../domain/payment_gateway.dart';
import 'fake_payment_gateway.dart';
import 'http_payment_gateway.dart';

/// Chwazi ki pasrèl UI a ap itilize.
///
/// Menm modèl ak `AuthRepositoryProvider`: yon sèl kote ki deside, epi tès yo
/// ka mete pa yo ak [override].
class PaymentGatewayProvider {
  PaymentGatewayProvider._();

  static PaymentGateway? _instance;

  static PaymentGateway get instance {
    return _instance ??= AppEnvironment.mockFirebase
        ? FakePaymentGateway()
        : HttpPaymentGateway();
  }

  /// Pou tès yo.
  static void override(PaymentGateway gateway) => _instance = gateway;

  static void reset() => _instance = null;
}
