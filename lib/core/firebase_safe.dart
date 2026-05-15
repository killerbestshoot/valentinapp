import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String firebaseErrorMessage(Object e) {
  // Firebase Auth
  if (e is FirebaseAuthException) {
    return e.message ?? e.code;
  }

  // Firebase (generic)
  if (e is FirebaseException) {
    return e.message ?? e.code;
  }

  // Web sometimes returns weird objects. Make it safe:
  return e.toString();
}

void safeLogError(Object e, [StackTrace? st]) {
  if (kDebugMode) {
    debugPrint('ERROR: $e');
    if (st != null) debugPrint('$st');
  }
}
