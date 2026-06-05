import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OtpSmsLoginScreen extends StatefulWidget {
  const OtpSmsLoginScreen({super.key});

  @override
  State<OtpSmsLoginScreen> createState() => _OtpSmsLoginScreenState();
}

class _OtpSmsLoginScreenState extends State<OtpSmsLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+52');
  final _codeCtrl = TextEditingController();

  bool _sending = false;
  bool _verifying = false;

  String? _verificationId;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty || !phone.startsWith('+')) {
      _toast('Mete nimewo a ak +. Eg: +52...');
      return;
    }

    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto verify (sou telefn reyl konn rive)
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) _toast('Konekte ');
        },
        verificationFailed: (FirebaseAuthException e) {
          _toast(e.message ?? 'Verify failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _toast('Kod la voye (si se test, mete 123456)');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();

    if (_verificationId == null) {
      _toast('Peze "Voye kod la" an premye.');
      return;
    }
    if (code.length != 6) {
      _toast('Kod la dwe gen 6 chif.');
      return;
    }

    setState(() => _verifying = true);

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) _toast('Konekte ');
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Kod la pa bon');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konekte (OTP SMS)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nimewo telefn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _sendCode,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Voye kod la'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kod OTP (6 chif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifying ? null : _verifyCode,
                child: _verifying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Konekte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
