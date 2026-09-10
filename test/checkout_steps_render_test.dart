import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n.dart';

import 'package:wizzo_market/core/network/api_client.dart';
import 'package:wizzo_market/core/theme/app_theme.dart';
import 'package:wizzo_market/features/account/models/profile.dart';
import 'package:wizzo_market/features/account/presentation/addresses_screen.dart';
import 'package:wizzo_market/features/cart/models/cart.dart';
import 'package:wizzo_market/features/cart/providers/cart_provider.dart';
import 'package:wizzo_market/features/catalog/models/product.dart';
import 'package:wizzo_market/features/checkout/data/checkout_repository.dart';
import 'package:wizzo_market/features/checkout/models/checkout.dart';
import 'package:wizzo_market/features/checkout/presentation/checkout_screen.dart';

class _StubCartController extends CartController {
  @override
  Future<CartData> build() async => const CartData(
    groups: [
      CartSellerGroup(
        sellerId: 'seller-user-1',
        sellerName: 'GreenGrocer Organics',
        items: [
          CartItem(
            id: 'ci-1',
            product: Product(
              id: 'prod-1',
              name: 'Drip Irrigation System',
              slug: 'drip-irrigation-system',
              images: [],
              price: 15473,
            ),
            sellerId: 'seller-user-1',
            sellerName: 'GreenGrocer Organics',
            quantity: 2,
          ),
        ],
      ),
    ],
    itemCount: 2,
    subtotal: 30946,
  );
}

class _FakeCheckoutRepository extends CheckoutRepository {
  _FakeCheckoutRepository()
    : super(ApiClient(baseUrl: 'https://example.invalid/api/v1'));

  @override
  Future<List<SellerPaymentInfo>> getSellersPaymentAccounts(
    List<String> sellerUserIds,
  ) async => const [];
}

void main() {
  testWidgets('CheckoutScreen renders content on every step', (tester) async {
    final cartRepoStub = _StubCartController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartProvider.overrideWith(() => cartRepoStub),
          addressesProvider.overrideWith(
            (ref) async => const AddressBook(
              addresses: [
                Address(
                  id: 'addr-1',
                  label: 'Home',
                  fullName: 'Checkout Test',
                  phone: '0788112233',
                  country: 'Rwanda',
                  city: 'Kigali',
                  street: 'KN 4 Ave',
                  isDefault: true,
                ),
              ],
            ),
          ),
          checkoutRepositoryProvider.overrideWith(
            (ref) => _FakeCheckoutRepository(),
          ),
        ],
        child: localizedApp(const CheckoutScreen(), theme: buildLightTheme()),
      ),
    );
    await tester.pumpAndSettle();

    // Step 0 — Cart summary
    expect(find.text('Order summary'), findsOneWidget);
    expect(find.text('GreenGrocer Organics'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);

    // Step 1 — Shipping
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Shipping'), findsWidgets);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Delivery method'), findsOneWidget);

    // Step 2 — Payment (final step)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Payment'), findsWidgets);
    expect(find.text('Mobile Money'), findsOneWidget);
    expect(find.text('Google Pay'), findsWidgets);
    expect(find.textContaining('Pay '), findsWidgets);
  });
}
