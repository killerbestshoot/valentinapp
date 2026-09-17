import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/data/auth_repository_provider.dart';
import '../../features/auth/domain/auth_repository.dart';
import 'session_store.dart';

/// Fèmen sesyon an lè moun nan sispann navige.
///
/// Li chita anwo tout ekran yo epi li tande dwèt sou ekran an, sourit la ak
/// klavye a. Chak evènman sa yo se yon siy prezans: li repouse kontè a. Si
/// kontè a rive nan [SessionStore.idleTimeout] (5 minit), nou dekonekte moun
/// nan epi wout yo voye l sou paj koneksyon an.
///
/// Poukisa isit la epi PA nan yon minitè sou chak ekran: yon ajan ki kite
/// telefòn li sou yon kontwa, oswa yon navigatè ki rete louvri nan yon sibè,
/// se la lajan an ye. Sesyon an dwe fèmen menm jan kèlkeswa ekran an.
///
/// Serveur a gen menm limit lan bò kote pa l (`SESSION_IDLE_MINUTES`): si yon
/// moun kopye jeton an, li pa vo anyen apre 5 minit san apèl. Minitè sa a se
/// pati vizib la — sa ki pwoteje vre a se serveur a.
class SessionTimeoutGuard extends StatefulWidget {
  const SessionTimeoutGuard({
    super.key,
    required this.child,
    this.authRepository,
    this.sessionStore,
    this.checkEvery = const Duration(seconds: 10),
  });

  final Widget child;

  /// Pou tès yo; pa defo se sa aplikasyon an sèvi.
  final AuthRepository? authRepository;
  final SessionStore? sessionStore;

  /// Chak konbyen tan nou gade kontè a. Nou pa remete yon `Timer` sou chak
  /// dwèt: yon ti verifikasyon regilye koute mwens e li wè tou lè aparèy la
  /// te nan dòmi.
  final Duration checkEvery;

  @override
  State<SessionTimeoutGuard> createState() => _SessionTimeoutGuardState();
}

class _SessionTimeoutGuardState extends State<SessionTimeoutGuard>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _closing = false;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryProvider.instance;

  SessionStore get _session => widget.sessionStore ?? SessionStore.instance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);

    _session.touch();
    _ticker = Timer.periodic(widget.checkEvery, (_) => _check());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lè app la tounen an premye plan, minitè a te ka pa kouri (aparèy nan
    // dòmi). Nou gade touswit olye nou tann pwochen tik la.
    if (state == AppLifecycleState.resumed) _check();
  }

  bool _onKey(KeyEvent event) {
    _onActivity();
    return false; // Nou tande sèlman: evènman an kontinye chemen l.
  }

  void _onActivity() => _session.touch();

  void _check() {
    if (_closing) return;
    if (_auth.currentUser == null) return;
    if (!_session.isIdle && !_session.isExpired) return;

    _closing = true;
    unawaited(_close());
  }

  Future<void> _close() async {
    // Paj koneksyon an li nòt sa a pou l di poukisa sesyon an fèmen.
    _session.markTimedOut();

    try {
      await _auth.signOut();
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // `translucent` = nou wè evènman yo pase, men nou pa pran yo nan men
      // bouton ak lis ki anba yo.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerMove: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
      child: widget.child,
    );
  }
}
