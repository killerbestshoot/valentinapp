# write_mvp.ps1
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path `
"lib\core\models", `
"lib\core\services", `
"lib\features\auth\presentation\pages", `
"lib\features\home\presentation\pages", `
"lib\app" | Out-Null

function WriteFile($path, $content) {
  $dir = Split-Path $path
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ---------------- app_router.dart ----------------
WriteFile "lib\app\app_router.dart" @"
import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/welcome_screen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/auth/presentation/pages/email_login_screen.dart';
import '../features/auth/presentation/pages/otp_screen.dart';

import '../features/home/presentation/pages/dashboard_screen.dart';

class AppRouter {
  static const welcome = '/';
  static const login = '/login';
  static const register = '/register';
  static const emailLogin = '/email-login';
  static const otp = '/otp';
  static const dashboard = '/dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case emailLogin:
        return MaterialPageRoute(builder: (_) => const EmailLoginScreen());
      case otp:
        return MaterialPageRoute(builder: (_) => const OtpScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
"@

# ---------------- app_user.dart ----------------
WriteFile "lib\core\models\app_user.dart" @"
enum UserRole { owner, admin, agent, customer }

UserRole roleFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'owner':
      return UserRole.owner;
    case 'admin':
      return UserRole.admin;
    case 'agent':
      return UserRole.agent;
    default:
      return UserRole.customer;
  }
}

String roleToString(UserRole r) => r.name;

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': roleToString(role),
      };

  static AppUser fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: roleFromString(map['role'] as String?),
    );
  }
}
"@

# ---------------- transaction.dart ----------------
WriteFile "lib\core\models\transaction.dart" @"
import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { cash_in, cash_out, western_union, cam_transfer }
enum TxStatus { pending, approved, paid, canceled }

TxType txTypeFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'cash_out':
      return TxType.cash_out;
    case 'western_union':
      return TxType.western_union;
    case 'cam_transfer':
      return TxType.cam_transfer;
    default:
      return TxType.cash_in;
  }
}

TxStatus txStatusFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'approved':
      return TxStatus.approved;
    case 'paid':
      return TxStatus.paid;
    case 'canceled':
      return TxStatus.canceled;
    default:
      return TxStatus.pending;
  }
}

class AppTransaction {
  final String id;
  final TxType type;
  final TxStatus status;
  final double amount;
  final String currency;
  final String senderName;
  final String receiverName;
  final String receiverPhone;
  final String createdByUid;
  final Timestamp createdAt;

  const AppTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    required this.senderName,
    required this.receiverName,
    required this.receiverPhone,
    required this.createdByUid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'status': status.name,
        'amount': amount,
        'currency': currency,
        'senderName': senderName,
        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
        'createdByUid': createdByUid,
        'createdAt': createdAt,
      };

  static AppTransaction fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return AppTransaction(
      id: doc.id,
      type: txTypeFromString(m['type'] as String?),
      status: txStatusFromString(m['status'] as String?),
      amount: (m['amount'] as num).toDouble(),
      currency: (m['currency'] ?? 'HTG') as String,
      senderName: (m['senderName'] ?? '') as String,
      receiverName: (m['receiverName'] ?? '') as String,
      receiverPhone: (m['receiverPhone'] ?? '') as String,
      createdByUid: (m['createdByUid'] ?? '') as String,
      createdAt: (m['createdAt'] ?? Timestamp.now()) as Timestamp,
    );
  }
}
"@

# ---------------- firestore_service.dart ----------------
WriteFile "lib\core\services\firestore_service.dart" @"
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/transaction.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _tx => _db.collection('transactions');

  Future<void> upsertUser(AppUser u) async {
    await _users.doc(u.uid).set(u.toMap(), SetOptions(merge: true));
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((s) {
      if (!s.exists) return null;
      return AppUser.fromMap(s.data()!);
    });
  }

  Stream<List<AppTransaction>> watchTransactions({
    required UserRole role,
    required String uid,
  }) {
    Query<Map<String, dynamic>> q = _tx.orderBy('createdAt', descending: true);
    if (role == UserRole.agent || role == UserRole.customer) {
      q = q.where('createdByUid', isEqualTo: uid);
    }
    return q.snapshots().map((snap) => snap.docs.map(AppTransaction.fromDoc).toList());
  }

  Future<void> updateTxStatus(String txId, TxStatus s) async {
    await _tx.doc(txId).update({'status': s.name});
  }

  Future<String> createTransaction({required AppTransaction tx}) async {
    final ref = await _tx.add(tx.toMap());
    return ref.id;
  }
}
"@

# ---------------- auth screens ----------------
WriteFile "lib\features\auth\presentation\pages\welcome_screen.dart" @"
import 'package:flutter/material.dart';
import '../../../../app/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRouter.login),
            child: const Text('Kontinye'),
          ),
        ),
      ),
    );
  }
}
"@

WriteFile "lib\features\auth\presentation\pages\login_screen.dart" @"
import 'package:flutter/material.dart';
import '../../../../app/app_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chwazi fason pou konekte'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRouter.emailLogin),
              child: const Text('Login ak Email'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRouter.register),
              child: const Text('Kreye kont'),
            ),
          ],
        ),
      ),
    );
  }
}
"@

WriteFile "lib\features\auth\presentation\pages\register_screen.dart" @"
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../app/app_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final u = AppUser(
        uid: cred.user!.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: UserRole.agent,
      );

      await FirestoreService.instance.upsertUser(u);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.dashboard, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erè: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Non')),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefòn')),
            const SizedBox(height: 12),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Modpas'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: Text(_loading ? 'Tann...' : 'Kreye kont'),
            ),
          ],
        ),
      ),
    );
  }
}
"@

WriteFile "lib\features\auth\presentation\pages\email_login_screen.dart" @"
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/app_router.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});
  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.dashboard, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erè: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Modpas'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: Text(_loading ? 'Tann...' : 'Konekte'),
            ),
          ],
        ),
      ),
    );
  }
}
"@

WriteFile "lib\features\auth\presentation\pages\otp_screen.dart" @"
import 'package:flutter/material.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('OTP ap vini pita (MVP: Email/Password)')),
    );
  }
}
"@

# ---------------- home screens ----------------
WriteFile "lib\features\home\presentation\pages\dashboard_screen.dart" @"
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/services/firestore_service.dart';

import 'transactions_page.dart';
import 'send_money_page.dart';
import 'receive_money_page.dart';
import 'agent_accounts_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Pa konekte.')));
    }

    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.watchUser(uid),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Chaje kont...')));
        }

        final pages = <Widget>[
          TransactionsPage(user: user),
          SendMoneyPage(user: user),
          ReceiveMoneyPage(user: user),
          AgentAccountsPage(user: user),
        ];

        final titles = const [
          'Tranzaksyon',
          'Voye Lajan',
          'Resevwa Lajan',
          'Ajan / Kont',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text('Dashboard - ${user.role.name.toUpperCase()}'),
            actions: [
              IconButton(
                onPressed: () async => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Byenvini ${user.name} 👋', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(titles.length, (i) {
                    return ChoiceChip(
                      label: Text(titles[i]),
                      selected: _index == i,
                      onSelected: (_) => setState(() => _index = i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Expanded(child: pages[_index]),
              ],
            ),
          ),
        );
      },
    );
  }
}
"@

WriteFile "lib\features\home\presentation\pages\transactions_page.dart" @"
import 'package:flutter/material.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/services/firestore_service.dart';

class TransactionsPage extends StatelessWidget {
  final AppUser user;
  const TransactionsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppTransaction>>(
      stream: FirestoreService.instance.watchTransactions(role: user.role, uid: user.uid),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const Center(child: Text('Pa gen tranzaksyon ankò.'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) {
            final t = items[i];
            return ListTile(
              title: Text('${t.type.name} • ${t.amount.toStringAsFixed(2)} ${t.currency}'),
              subtitle: Text('Pou: ${t.receiverName} (${t.receiverPhone}) • ${t.status.name}'),
              trailing: (user.role == UserRole.owner || user.role == UserRole.admin)
                  ? PopupMenuButton<TxStatus>(
                      onSelected: (s) => FirestoreService.instance.updateTxStatus(t.id, s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: TxStatus.pending, child: Text('pending')),
                        PopupMenuItem(value: TxStatus.approved, child: Text('approved')),
                        PopupMenuItem(value: TxStatus.paid, child: Text('paid')),
                        PopupMenuItem(value: TxStatus.canceled, child: Text('canceled')),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
"@

WriteFile "lib\features\home\presentation\pages\send_money_page.dart" @"
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/services/firestore_service.dart';

class SendMoneyPage extends StatefulWidget {
  final AppUser user;
  const SendMoneyPage({super.key, required this.user});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  final _senderCtrl = TextEditingController();
  final _recvCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  TxType _type = TxType.cash_in;
  String _currency = 'HTG';
  bool _loading = false;

  @override
  void dispose() {
    _senderCtrl.dispose();
    _recvCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete yon montan valab.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final tx = AppTransaction(
        id: '',
        type: _type,
        status: TxStatus.pending,
        amount: amount,
        currency: _currency,
        senderName: _senderCtrl.text.trim(),
        receiverName: _recvCtrl.text.trim(),
        receiverPhone: _phoneCtrl.text.trim(),
        createdByUid: widget.user.uid,
        createdAt: Timestamp.now(),
      );

      await FirestoreService.instance.createTransaction(tx: tx);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tranzaksyon kreye ✅')),
      );
      _senderCtrl.clear();
      _recvCtrl.clear();
      _phoneCtrl.clear();
      _amountCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erè: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        DropdownButtonFormField<TxType>(
          value: _type,
          items: const [
            DropdownMenuItem(value: TxType.cash_in, child: Text('MonCash / Cash In')),
            DropdownMenuItem(value: TxType.cash_out, child: Text('Cash Out')),
            DropdownMenuItem(value: TxType.western_union, child: Text('Western Union')),
            DropdownMenuItem(value: TxType.cam_transfer, child: Text('CAM Transfer')),
          ],
          onChanged: (v) => setState(() => _type = v ?? TxType.cash_in),
          decoration: const InputDecoration(labelText: 'Kalite tranzaksyon'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _senderCtrl, decoration: const InputDecoration(labelText: 'Non moun k ap voye')),
        const SizedBox(height: 12),
        TextField(controller: _recvCtrl, decoration: const InputDecoration(labelText: 'Non moun k ap resevwa')),
        const SizedBox(height: 12),
        TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefòn reseptè')),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montan'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _currency,
          items: const [
            DropdownMenuItem(value: 'HTG', child: Text('HTG')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'DOP', child: Text('DOP')),
          ],
          onChanged: (v) => setState(() => _currency = v ?? 'HTG'),
          decoration: const InputDecoration(labelText: 'Lajan'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _create,
          child: Text(_loading ? 'Anrejistre...' : 'Anrejistre Tranzaksyon'),
        ),
      ],
    );
  }
}
"@

WriteFile "lib\features\home\presentation\pages\receive_money_page.dart" @"
import 'package:flutter/material.dart';
import '../../../../core/models/app_user.dart';

class ReceiveMoneyPage extends StatelessWidget {
  final AppUser user;
  const ReceiveMoneyPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Resevwa Lajan (MVP): itilize “Voye Lajan” pou kreye tranzaksyon, admin ap validate.'),
    );
  }
}
"@

WriteFile "lib\features\home\presentation\pages\agent_accounts_page.dart" @"
import 'package:flutter/material.dart';
import '../../../../core/models/app_user.dart';

class AgentAccountsPage extends StatelessWidget {
  final AppUser user;
  const AgentAccountsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.role != UserRole.owner && user.role != UserRole.admin) {
      return const Center(child: Text('Aksè limite: Admin/Owner sèlman.'));
    }
    return const Center(
      child: Text('Admin Panel (MVP): etap swivan = kreye/edite agent, limit, komisyon.'),
    );
  }
}
"@

Write-Host "DONE ✅ Script ekri tout fichye yo."
