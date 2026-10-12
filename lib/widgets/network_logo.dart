import 'package:flutter/material.dart';

/// Logo yon rezo peman: MonCash, NatCash, oswa bank.
///
/// Imaj yo se `assets/logos/moncash.png` ak `assets/logos/natcash.png`. Si
/// fichye a manke (oswa rezo a enkoni), nou montre yon badj ak lèt la ak koulè
/// rezo a — UI a pa janm kase pou yon imaj.
class NetworkLogo extends StatelessWidget {
  const NetworkLogo(this.network, {super.key, this.size = 36});

  /// `moncash`, `natcash`, `bank`, oswa yon non sèvis ("MonCash", "NatCash"...).
  final String network;
  final double size;

  static const moncashColor = Color(0xFFC8102E);
  static const natcashColor = Color(0xFF0B5FA5);
  static const bankColor = Color(0xFF334155);

  static String? _key(String value) {
    final v = value.toLowerCase();
    if (v.contains('moncash')) return 'moncash';
    if (v.contains('natcash')) return 'natcash';
    if (v.contains('bank')) return 'bank';
    return null;
  }

  /// Koulè rezo a, pou chip, bòdi, elatriye.
  static Color colorOf(String network) => switch (_key(network)) {
        'moncash' => moncashColor,
        'natcash' => natcashColor,
        _ => bankColor,
      };

  /// Non pou montre: "MonCash", "NatCash", "Bank".
  static String labelOf(String network) => switch (_key(network)) {
        'moncash' => 'MonCash',
        'natcash' => 'NatCash',
        'bank' => 'Virement bancaire',
        _ => network,
      };

  @override
  Widget build(BuildContext context) {
    final key = _key(network);
    final radius = BorderRadius.circular(size * 0.24);

    if (key == 'bank') {
      return _badge(radius, child: Icon(Icons.account_balance_outlined, color: Colors.white, size: size * 0.56));
    }

    final fallback = _badge(
      radius,
      child: Text(
        key == null ? (network.isEmpty ? '?' : network[0].toUpperCase()) : key[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.46),
      ),
    );
    if (key == null) return fallback;

    // `contain` sou fon blan: logo MonCash la gen maj blan, `cover` ta koupe l.
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          'assets/logos/$key.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: labelOf(key),
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Widget _badge(BorderRadius radius, {required Widget child}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colorOf(network), borderRadius: radius),
        child: child,
      );
}
