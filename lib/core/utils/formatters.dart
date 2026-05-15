class Formatters {
  Formatters._();

  static String money(num v, String currency) =>
      '${v.toStringAsFixed(2)} $currency';
}
