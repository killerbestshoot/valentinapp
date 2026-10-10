import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Yon antre nan meni bò a.
class ShellDestination {
  const ShellDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.section = '',
    this.badge = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  /// Tit gwoup la (Operasyon, Lajan, Sistèm...). Vid = premye gwoup la.
  final String section;

  /// Montre kantite notifikasyon an sou antre sa a.
  final bool badge;
}

/// Kad owner/admin: meni bò a (aksyon yo), ba anlè (paj la + moun ki konekte),
/// epi paj chwazi a nan mitan.
///
/// Gwo ekran: meni an toujou la, li ka pliye an ikòn. Telefòn: li louvri nan
/// yon tiwa (☰). Paj yo pa pouse youn sou lòt: meni an chanje sa ki nan mitan.
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.destinations,
    required this.onCreateTransaction,
    this.onRefresh,
    this.initial = 0,
  });

  final List<ShellDestination> destinations;
  final VoidCallback onCreateTransaction;

  /// Bouton rafrechi nan ba anlè a (paj Tablo a sèlman).
  final void Function(String destinationId)? onRefresh;
  final int initial;

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  static const _wideBreakpoint = 1000.0;

  late int _index = widget.initial;
  bool _collapsed = false;
  int _notifications = 0;
  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Kanal tan reyèl la rete ouvè tout tan kad la la.
    Realtime.instance.retain();
    _live = Realtime.instance.listen(
      const {'topups', 'payouts', 'transfers', 'transactions', 'users'},
      _loadNotifications,
    );
  }

  @override
  void dispose() {
    _live?.cancel();
    Realtime.instance.release();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final items = await SystemApi.instance.notifications();
      if (!mounted) return;
      setState(() => _notifications =
          items.fold(0, (s, n) => s + (n.count > 0 ? n.count : 1)));
    } catch (_) {
      // Badj la se yon konfò: si li pa chaje, meni an rete itilizab.
    }
  }

  /// Chanje paj depi deyò kad la (egz. bouton "Mande payout" sou akèy ajan an).
  void select(String destinationId) {
    final i = widget.destinations.indexWhere((d) => d.id == destinationId);
    if (i >= 0) _select(i);
  }

  void _select(int i, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.of(context).pop();
    if (i == _index) return;
    setState(() => _index = i);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dekonekte?'),
        content: const Text('Ou vle soti nan kont sa a?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Anile')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Dekonekte'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthRepositoryProvider.instance.signOut();
  }

  void _openSettings() {
    final i = widget.destinations.indexWhere((d) => d.id == 'settings');
    if (i >= 0) _select(i);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.destinations[_index];

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      final menu = _SideMenu(
        destinations: widget.destinations,
        selected: _index,
        collapsed: wide && _collapsed,
        notifications: _notifications,
        onSelect: (i) => _select(i, closeDrawer: !wide),
        onCreate: () {
          if (!wide) Navigator.of(context).pop();
          widget.onCreateTransaction();
        },
        onLogout: _logout,
      );

      final body = ShellScope(
        child: KeyedSubtree(
            key: ValueKey(current.id), child: current.builder(context)),
      );

      return Scaffold(
        backgroundColor: DashboardColors.surface,
        drawer: wide ? null : Drawer(width: 280, child: SafeArea(child: menu)),
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _collapsed ? 76 : 256,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        right: BorderSide(color: DashboardColors.border)),
                  ),
                  child: menu,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: current.label,
                      wide: wide,
                      collapsed: _collapsed,
                      onToggleMenu: () =>
                          setState(() => _collapsed = !_collapsed),
                      onRefresh: widget.onRefresh == null
                          ? null
                          : () => widget.onRefresh!(current.id),
                      notifications: _notifications,
                      onNotifications: () {
                        final i =
                            widget.destinations.indexWhere((d) => d.badge);
                        if (i >= 0) _select(i);
                      },
                      onSettings: _openSettings,
                      onLogout: _logout,
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Meni bò a
// ---------------------------------------------------------------------------

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.destinations,
    required this.selected,
    required this.collapsed,
    required this.notifications,
    required this.onSelect,
    required this.onCreate,
    required this.onLogout,
  });

  final List<ShellDestination> destinations;
  final int selected;
  final bool collapsed;
  final int notifications;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    String? section;
    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.section != section) {
        section = d.section;
        if (d.section.isNotEmpty) {
          items.add(collapsed
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(indent: 18, endIndent: 18))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                  child: Text(d.section.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w800,
                          color: DashboardColors.muted)),
                ));
        }
      }
      items.add(_MenuItem(
        destination: d,
        selected: i == selected,
        collapsed: collapsed,
        badge: d.badge ? notifications : 0,
        onTap: () => onSelect(i),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 18 : 20, 18, 12, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: DashboardColors.brand,
                    borderRadius: BorderRadius.circular(11)),
                child: const Text('V',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19)),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('VOUPVAPCASH',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: DashboardColors.ink)),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 16),
          child: Tooltip(
            message: collapsed ? 'Nouvo tranzaksyon' : '',
            child: FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: DashboardColors.brand,
                minimumSize: const Size.fromHeight(46),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: collapsed
                  ? const Icon(Icons.add)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                            child: Text('Nouvo tranzaksyon',
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.only(bottom: 12), children: items)),
        const Divider(height: 1),
        _UserCard(collapsed: collapsed, onLogout: onLogout),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.badge,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool collapsed;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? DashboardColors.brand
        : DashboardColors.ink.withValues(alpha: 0.82);
    final icon = Badge(
      isLabelVisible: badge > 0,
      label: Text(badge > 99 ? '99+' : '$badge'),
      backgroundColor: DashboardColors.danger,
      child: Icon(destination.icon, size: 21, color: fg),
    );

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: collapsed ? 12 : 10, vertical: 1),
      child: Tooltip(
        message: collapsed ? destination.label : '',
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: selected ? DashboardColors.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              child: collapsed
                  ? icon
                  : Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destination.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: DashboardColors.brand,
                                shape: BoxShape.circle),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _roleLabel(AppRole? role) => switch (role) {
      AppRole.owner => 'Pwopriyetè',
      AppRole.admin => 'Administratè',
      AppRole.agent => 'Ajan',
      _ => '',
    };

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'[\s@._-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.collapsed, required this.onLogout});

  final bool collapsed;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName
        : (user?.email ?? '');
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: DashboardColors.soft,
      child: Text(_initials(name),
          style: const TextStyle(
              color: DashboardColors.brand,
              fontWeight: FontWeight.w900,
              fontSize: 13)),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Tooltip(message: name, child: avatar),
          IconButton(
              tooltip: 'Dekonekte',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 20)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  [_roleLabel(user?.role), user?.enterpriseName ?? '']
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: DashboardColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
              tooltip: 'Dekonekte',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 20)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ba anlè
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.wide,
    required this.collapsed,
    required this.onToggleMenu,
    required this.notifications,
    required this.onNotifications,
    required this.onSettings,
    required this.onLogout,
    this.onRefresh,
  });

  final String title;
  final bool wide;
  final bool collapsed;
  final VoidCallback onToggleMenu;
  final VoidCallback? onRefresh;
  final int notifications;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName
        : (user?.email ?? '');

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: DashboardColors.surface,
        border: Border(bottom: BorderSide(color: DashboardColors.border)),
      ),
      // Lajè BA a, pa lajè ekran an: sou telefòn (oswa ak meni an louvri) non
      // moun nan ak etikèt "An dirèk" la kache pou pa gen debòdman.
      child: LayoutBuilder(builder: (context, box) {
        final showName = box.maxWidth >= 600;
        final showLiveLabel = box.maxWidth >= 700;
        return Row(
          children: [
            wide
                ? IconButton(
                    tooltip: collapsed ? 'Louvri meni an' : 'Pliye meni an',
                    onPressed: onToggleMenu,
                    icon: Icon(collapsed ? Icons.menu_open : Icons.menu),
                  )
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Meni',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: DashboardColors.ink)),
            ),
            _LiveIndicator(showLabel: showLiveLabel),
            if (onRefresh != null)
              IconButton(
                  tooltip: 'Rafrechi',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh)),
            IconButton(
              tooltip: 'Notifikasyon',
              onPressed: onNotifications,
              icon: Badge(
                isLabelVisible: notifications > 0,
                label: Text(notifications > 99 ? '99+' : '$notifications'),
                backgroundColor: DashboardColors.danger,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Kont ou',
              position: PopupMenuPosition.under,
              onSelected: (v) => v == 'logout' ? onLogout() : onSettings(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: DashboardColors.ink)),
                      Text(user?.email ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: DashboardColors.muted)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('Paramèt'),
                        dense: true)),
                const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Dekonekte'),
                        dense: true)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: DashboardColors.brand,
                      child: Text(_initials(name),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5)),
                    ),
                    if (showName) ...[
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                            Text(_roleLabel(user?.role),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: DashboardColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more,
                          size: 18, color: DashboardColors.muted),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// "An dirèk": vèt lè kanal tan reyèl la ouvè, gri lè l ap rekonekte.
class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Realtime.instance.connected,
      builder: (context, live, _) => Tooltip(
        message: live
            ? 'An dirèk: ekran an mete l ajou poukont li'
            : 'N ap rekonekte... done yo ka pa a jou',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: live ? const Color(0xFF15803D) : DashboardColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 6),
                Text(live ? 'An dirèk' : 'Rekoneksyon...',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: live
                            ? const Color(0xFF15803D)
                            : DashboardColors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
