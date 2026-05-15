class PinService {
  // DEMO local (pa backend)
  static String? _pin;

  static bool hasPin() => _pin != null;

  static void setPin(String pin) {
    _pin = pin;
  }

  static bool verify(String pin) {
    return _pin == pin;
  }

  static void clear() {
    _pin = null;
  }
}
