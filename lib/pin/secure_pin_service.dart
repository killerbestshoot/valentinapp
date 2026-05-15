class SecurePinService {
  String? _savedPin;

  Future<void> savePin(String pin) async {
    _savedPin = pin;
  }

  Future<bool> verifyPin(String pin) async {
    return _savedPin == pin;
  }
}
