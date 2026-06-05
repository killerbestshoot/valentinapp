import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/session/app_session.dart';
import '../../../client_portal/presentation/pages/client_portal_page.dart';
import '../../../dashboard/presentation/pages/services_dashboard_page.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({super.key});

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  Future<void> _goToRoleHome(AppRole role) async {
    Widget page;

    switch (role) {
      case AppRole.client:
        page = const ClientPortalPage();
        break;
      case AppRole.owner:
      case AppRole.admin:
      case AppRole.agent:
        page = const ServicesDashboardPage();
        break;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _loadEnterpriseUser(User firebaseUser) async {
    final query = await FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('uid', isEqualTo: firebaseUser.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Itilizat sa pa jwenn nan enterprise_users');
    }

    final data = query.docs.first.data();

    final active = (data['isActive'] ?? true) == true;
    if (!active) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Kont sa dezaktive');
    }

    final role = AppRoleX.fromString((data['role'] ?? 'agent').toString());
    final displayName = (data['displayName'] ?? 'Itilizat').toString();
    final enterpriseName =
        (data['enterpriseName'] ?? AppBrand.defaultEnterpriseName).toString();
    final enterpriseId =
        (data['enterpriseId'] ?? AppBrand.defaultEnterpriseId).toString();

    AppSession.apply(
      userId: firebaseUser.uid,
      userName: displayName,
      userEmail: firebaseUser.email ?? '',
      role: role,
      enterprise: enterpriseName,
      enterpriseUid: enterpriseId,
      active: active,
    );

    await _goToRoleHome(role);
  }

  Future<void> _checkExistingLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _loadEnterpriseUser(user);
    } catch (_) {}
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete email ak modpas la')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Login pa reyisi');
      }

      await _loadEnterpriseUser(user);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login pa mache';

      switch (e.code) {
        case 'invalid-email':
          msg = 'Email la pa valid';
          break;
        case 'user-not-found':
          msg = 'Kont sa pa egziste';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Email oswa modpas pa bon';
          break;
        case 'too-many-requests':
          msg = 'Twp es. Tann yon ti moman';
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Er: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingLogin();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _infoCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppBrand.loginTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Login reyl antrepriz la',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Modpas',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _hidePassword = !_hidePassword);
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: const Icon(Icons.login),
                        label: Text(_loading ? 'Ap konekte...' : 'Antre'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _infoCard(
              'Antrepriz',
              'Non antrepriz la ap soti dirk nan Firestore: ${AppBrand.defaultEnterpriseName}',
              Icons.business,
            ),
            const SizedBox(height: 10),
            _infoCard(
              'Wl yo',
              'owner / admin / agent / client soti dirk nan Firestore.',
              Icons.verified_user,
            ),
            const SizedBox(height: 10),
            _infoCard(
              'Kliyan',
              'Kliyan se moun k ap resevwa svis sou platfm nan.',
              Icons.person,
            ),
          ],
        ),
      ),
    );
  }
}
