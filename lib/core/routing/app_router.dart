import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/about_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/addresses_screen.dart';
import '../../features/account/presentation/appearance_screen.dart';
import '../../features/account/presentation/change_email_screen.dart';
import '../../features/account/presentation/change_password_screen.dart';
import '../../features/account/presentation/currency_screen.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/help_screen.dart';
import '../../features/account/presentation/language_screen.dart';
import '../../features/account/presentation/legal_screen.dart';
import '../../features/account/presentation/notification_settings_screen.dart';
import '../../features/account/presentation/order_detail_screen.dart';
import '../../features/account/presentation/orders_screen.dart';
import '../../features/account/presentation/payment_methods_screen.dart';
import '../../features/account/presentation/reviews_screen.dart';
import '../../features/account/presentation/wallet_screen.dart';
import '../../features/account/presentation/wishlist_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/role_choice_screen.dart';
import '../../features/auth/presentation/buyer_signup_screen.dart';
import '../../features/auth/presentation/seller_signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/browse_screen.dart';
import '../../features/catalog/presentation/home_screen.dart';
import '../../features/catalog/presentation/nearby_sellers_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/search_screen.dart';
import '../../features/catalog/presentation/shop_screen.dart';
import '../../features/checkout/models/checkout.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/deals_screen.dart';
import '../../features/checkout/presentation/order_confirmation_screen.dart';
import '../../features/messages/presentation/conversation_screen.dart';
import '../../features/videos/presentation/shorts_feed_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/catalog/models/product.dart';
import '../../features/seller/presentation/create_store_screen.dart';
import '../../features/seller/presentation/my_products_screen.dart';
import '../../features/seller/presentation/payment_accounts_screen.dart';
import '../../features/seller/presentation/product_form_screen.dart';
import '../../features/seller/presentation/seller_home_screen.dart';
import '../../features/seller/presentation/seller_earnings_screen.dart';
import '../../features/seller/presentation/seller_funds_screen.dart';
import '../../features/seller/presentation/seller_order_detail_screen.dart';
import '../../features/seller/presentation/seller_orders_screen.dart';
import '../../features/seller/presentation/store_settings_screen.dart';
import '../widgets/bottom_nav.dart';

/// Shared route observer so screens can react to being covered/uncovered by
/// another route (e.g. the shorts feed pauses its video when a page is pushed
/// on top of it).
final appRouteObserver = RouteObserver<ModalRoute<void>>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final goRouter = GoRouter(
    initialLocation: '/home',
    observers: [appRouteObserver],
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider).isSignedIn;
      final path = state.matchedLocation;
      final splashish =
          path == '/login' ||
          path == '/onboarding' ||
          path == '/forgot-password' ||
          path == '/role-choice' ||
          path == '/sign-up' ||
          path == '/sign-up-seller';
      if (!loggedIn && !splashish) return '/onboarding';
      if (loggedIn && splashish) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/role-choice',
        builder: (_, _) => const RoleChoiceScreen(),
      ),
      GoRoute(path: '/sign-up', builder: (_, _) => const BuyerSignUpScreen()),
      GoRoute(
        path: '/sign-up-seller',
        builder: (_, _) => const SellerSignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            WMarketShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
              ..._buildSharedRoutes(),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const AccountScreen(),
              ),
              ..._buildSharedRoutes(),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(goRouter.dispose);
  return goRouter;
});

/// Shared absolute routes registered in every shell branch so the bottom
/// navigation stays visible while browsing pushed pages.
List<RouteBase> _buildSharedRoutes() => [
  GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
  GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
  GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
  GoRoute(
    path: '/order-confirmation',
    redirect: (_, state) => state.extra == null ? '/home' : null,
    builder: (_, state) =>
        OrderConfirmationScreen(summary: state.extra as PlacementSummary?),
  ),
  GoRoute(
    path: '/product/:id',
    builder: (_, state) =>
        ProductDetailScreen(productId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/browse/:slug',
    builder: (_, state) => BrowseScreen(slug: state.pathParameters['slug']!),
  ),
  GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
  GoRoute(
    path: '/notifications',
    builder: (_, _) => const NotificationsScreen(),
  ),
  GoRoute(
    path: '/conversation/:id',
    builder: (_, state) =>
        ConversationScreen(conversationId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/shop/:slug',
    builder: (_, state) => ShopScreen(storeSlug: state.pathParameters['slug']!),
  ),
  GoRoute(
    path: '/shorts',
    builder: (_, state) {
      final store = state.uri.queryParameters['store'];
      final product = state.uri.queryParameters['product'];
      return ShortsFeedScreen(store: store, startProductId: product);
    },
  ),
  GoRoute(
    path: '/sellers/nearby',
    builder: (_, _) => const NearbySellersScreen(),
  ),
  GoRoute(path: '/deals/all', builder: (_, _) => const DealsAllScreen()),
  GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
  GoRoute(
    path: '/order/:id',
    builder: (_, state) =>
        OrderDetailScreen(orderId: state.pathParameters['id']!),
  ),
  // Seller dashboard
  GoRoute(path: '/seller', builder: (_, _) => const SellerGateScreen()),
  GoRoute(
    path: '/seller/create-store',
    builder: (_, _) => const CreateStoreScreen(),
  ),
  GoRoute(
    path: '/seller/products',
    builder: (_, _) => const MyProductsScreen(),
  ),
  GoRoute(
    path: '/seller/product/new',
    builder: (_, _) => const ProductFormScreen(),
  ),
  GoRoute(
    path: '/seller/product/:id/edit',
    builder: (_, state) => ProductFormScreen(
      product: state.extra is Product ? state.extra! as Product : null,
    ),
  ),
  GoRoute(
    path: '/seller/orders',
    builder: (_, _) => const SellerOrdersScreen(),
  ),
  GoRoute(
    path: '/seller/order/:id',
    builder: (_, state) =>
        SellerOrderDetailScreen(orderId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/seller/earnings',
    builder: (_, _) => const SellerEarningsScreen(),
  ),
  GoRoute(path: '/seller/funds', builder: (_, _) => const SellerFundsScreen()),
  GoRoute(
    path: '/seller/payment-accounts',
    builder: (_, _) => const PaymentAccountsScreen(),
  ),
  GoRoute(
    path: '/seller/settings',
    builder: (_, _) => const StoreSettingsScreen(),
  ),
  GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
  GoRoute(path: '/addresses', builder: (_, _) => const AddressesScreen()),
  GoRoute(
    path: '/payment-methods',
    builder: (_, _) => const PaymentMethodsScreen(),
  ),
  GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
  GoRoute(path: '/reviews', builder: (_, _) => const ReviewsScreen()),
  GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
  GoRoute(path: '/language', builder: (_, _) => const LanguageScreen()),
  GoRoute(path: '/currency', builder: (_, _) => const CurrencyScreen()),
  GoRoute(path: '/appearance', builder: (_, _) => const AppearanceScreen()),
  GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
  GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
  GoRoute(path: '/terms', builder: (_, _) => const TermsScreen()),
  GoRoute(path: '/edit-profile', builder: (_, _) => const EditProfileScreen()),
  GoRoute(path: '/change-email', builder: (_, _) => const ChangeEmailScreen()),
  GoRoute(
    path: '/change-password',
    builder: (_, _) => const ChangePasswordScreen(),
  ),
  GoRoute(
    path: '/notification-settings',
    builder: (_, _) => const NotificationSettingsScreen(),
  ),
];
