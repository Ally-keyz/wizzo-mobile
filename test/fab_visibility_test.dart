import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Minimal re-creation of the WMarketShell FAB visibility decision.
/// The FAB is shown only when the deepest matched leaf is exactly `/home`.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.navigationShell,
    required this.useMatchedLocation,
  });

  final StatefulNavigationShell navigationShell;
  final bool useMatchedLocation;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return Scaffold(
      body: navigationShell,
      floatingActionButton: ListenableBuilder(
        listenable: router.routerDelegate,
        builder: (context, _) {
          final config = router.routerDelegate.currentConfiguration;
          final bool showFab;
          if (useMatchedLocation) {
            showFab = config.lastOrNull?.matchedLocation == '/home';
          } else {
            showFab = config.uri.path == '/home';
          }
          if (!showFab) return const SizedBox.shrink();
          return FloatingActionButton(heroTag: 'chat_fab', onPressed: () {});
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: TextButton(
          onPressed: () => context.push('/cart'),
          child: const Text('Open cart'),
        ),
      ),
    );
  }
}

class _CartScreen extends StatelessWidget {
  const _CartScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Cart')));
  }
}

class _AccountScreen extends StatelessWidget {
  const _AccountScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Account')));
  }
}

GoRouter _buildRouter({required bool useMatchedLocation}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _Shell(
          navigationShell: navigationShell,
          useMatchedLocation: useMatchedLocation,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const _HomeScreen()),
              GoRoute(
                path: '/account',
                builder: (_, _) => const _AccountScreen(),
              ),
              GoRoute(path: '/cart', builder: (_, _) => const _CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const _AccountScreen(),
              ),
              GoRoute(path: '/cart', builder: (_, _) => const _CartScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

void expectFab(WidgetTester tester, bool visible) {
  final fab = find.byType(FloatingActionButton);
  expect(
    fab.evaluate().isNotEmpty,
    visible,
    reason: 'Expected FAB ${visible ? 'visible' : 'hidden'}',
  );
}

void main() {
  testWidgets(
    'FAB logic hides on /cart and /account after push and tab switches',
    (tester) async {
      final router = _buildRouter(useMatchedLocation: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      // Home: FAB visible.
      expectFab(tester, true);

      // Account tab: FAB hidden.
      router.go('/account');
      await tester.pumpAndSettle();
      expectFab(tester, false);

      // Back to home, then imperative push of /cart: FAB must hide.
      router.go('/home');
      await tester.pumpAndSettle();
      expectFab(tester, true);

      await tester.tap(find.text('Open cart'));
      await tester.pumpAndSettle();
      expect(find.text('Cart'), findsOneWidget);
      expectFab(tester, false);
    },
  );
}
