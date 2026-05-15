class OtpApi {
  static Future<bool> sendOtp(String phone) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  static Future<bool> verifyOtp(String code) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
