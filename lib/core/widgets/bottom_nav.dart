import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/messages/providers/chat_providers.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/models/notification.dart';
import '../theme/app_colors.dart';
import 'w_widgets.dart';

/// The 3-item bottom navigation: Home, Sell, Account.
///
/// Also hosts the live in-app notification poller: while the app is in the
/// foreground it re-checks for new notifications and surfaces a banner when
/// something enabled in Notification Settings arrives.
class WMarketShell extends ConsumerStatefulWidget {
  const WMarketShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<WMarketShell> createState() => _WMarketShellState();
}

class _WMarketShellState extends ConsumerState<WMarketShell>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 20);

  Timer? _pollTimer;
  Timer? _bannerHideTimer;
  List<String> _lastSeenIds = const [];
  String? _lastShownKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPolling());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _bannerHideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || !ref.read(authControllerProvider).isSignedIn) return;

    final List<AppNotification> latest;
    try {
      latest = await ref.read(notificationRepositoryProvider).list();
    } catch (_) {
      return; // Offline or transient failure — try again next tick.
    }

    final prefs = ref.read(notificationPrefsProvider);
    final justArrived = <AppNotification>[];
    for (final n in latest) {
      if (!_lastSeenIds.contains(n.id) && !n.read && prefs.enabledFor(n.type)) {
        justArrived.add(n);
      }
    }
    _lastSeenIds = [for (final n in latest) n.id];

    // Keep the in-memory list + unread badge fresh in the background.
    await ref.read(notificationsProvider.notifier).seed(latest);

    if (!mounted || justArrived.isEmpty) return;
    final location = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.lastOrNull?.matchedLocation;
    if (location == '/notifications') return; // Already looking at them.

    // The same unread set must not be shown again (e.g. after a re-connect or
    // a lifecycle resume), otherwise the banner would never "go away" because
    // every poll re-shows it. A notification is surfaced exactly once; a new
    // arrival produces a new set and shows again.
    final bannerKey = [for (final n in justArrived) n.id]..sort();
    if (bannerKey.join(',') == _lastShownKey) return;
    _lastShownKey = bannerKey.join(',');

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          justArrived.length == 1
              ? justArrived.first.title
              : context.tr(
                  'common.newNotifications',
                  namedArgs: {'count': '${justArrived.length}'},
                ),
        ),
        action: SnackBarAction(
          label: context.tr('common.view'),
          onPressed: () => context.push('/notifications'),
        ),
      ),
    );

    // Guaranteed self-dismissal: hide it explicitly after the standard
    // duration instead of relying on the ambient auto-hide timer, which can be
    // reset or skipped when the banner overlaps a branch change or re-show.
    _bannerHideTimer?.cancel();
    _bannerHideTimer = Timer(const Duration(seconds: 4), () {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(messagesUnreadProvider);
    // Chat pages (messages list + conversation) report their presence and keep
    // the chat FAB hidden here, so it never overlaps the chat UI.
    final hideFab = ref.watch(chatPagesOpenProvider) > 0;
    // The chat FAB is only shown on the home page root. On every other page
    // (account, pushed routes like cart/product/checkout, chat pages, ...) it
    // is hidden so it never floats over unrelated UI.
    final router = GoRouter.of(context);
    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: ListenableBuilder(
        listenable: router.routerDelegate,
        builder: (context, _) {
          if (hideFab) return const SizedBox.shrink();
          // Use the deepest matched leaf location (not `uri`): go_router
          // excludes imperative pushes (cart, product, checkout, ...) from
          // `currentConfiguration.uri`, so it would keep reporting `/home`.
          final location = router
              .routerDelegate
              .currentConfiguration
              .lastOrNull
              ?.matchedLocation;
          final showFab = location == '/home';
          if (!showFab) return const SizedBox.shrink();
          return FloatingActionButton(
            heroTag: 'chat_fab',
            onPressed: () => context.push('/messages'),
            tooltip: context.tr('nav.messages'),
            backgroundColor: Palette.gold,
            foregroundColor: Colors.black,
            elevation: 4,
            shape: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (unread.value != null && unread.value! > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: WBadge(count: unread.value!),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (arrayIndex, branch) {
          if (arrayIndex == 1) {
            _openSell(context, ref);
            return;
          }
          widget.navigationShell.goBranch(
            branch,
            initialLocation: branch == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }

  void _openSell(BuildContext context, WidgetRef ref) {
    final signedIn = ref.read(authControllerProvider).isSignedIn;
    if (!signedIn) {
      context.go('/login?ref=create-store');
      return;
    }
    context.go('/seller');
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final void Function(int arrayIndex, int branch) onTap;

  static const _tabs =
      <({String labelKey, IconData icon, IconData activeIcon, int branch})>[
        (
          labelKey: 'nav.home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          branch: 0,
        ),
        (
          labelKey: 'nav.sell',
          icon: Icons.add,
          activeIcon: Icons.add,
          branch: -1,
        ),
        (
          labelKey: 'nav.account',
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          branch: 1,
        ),
      ];

  static const _sellIndex = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _item(context, 0, scheme),
              _sellButton(context, scheme),
              _item(context, 2, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int arrayIndex, ColorScheme scheme) {
    final tab = _tabs[arrayIndex];
    final active = currentIndex == tab.branch;
    final color = active ? Palette.gold : scheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(arrayIndex, tab.branch),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              context.tr(tab.labelKey),
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellButton(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      width: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: () => onTap(_sellIndex, -1),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Palette.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Palette.gold.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, size: 30, color: Colors.black),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            child: Text(
              context.tr(_tabs[1].labelKey),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
