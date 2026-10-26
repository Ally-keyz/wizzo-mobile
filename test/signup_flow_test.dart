import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n.dart';

import 'package:wizzo_market/core/theme/app_theme.dart';
import 'package:wizzo_market/features/auth/presentation/buyer_signup_screen.dart';
import 'package:wizzo_market/features/auth/presentation/seller_signup_screen.dart';

void main() {
  testWidgets('Buyer sign-up: Continue advances to the password step', (
    tester,
  ) async {
    await _usePhoneViewport(tester);

    await tester.pumpWidget(
      ProviderScope(child: localizedApp(const BuyerSignUpScreen(), theme: buildLightTheme())),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'Aline Uwase');
    await tester.enterText(fields.at(1), 'aline@example.com');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('aline@example.com'), findsOneWidget);
  });

  // Regression: `Validators.fullName(...) ?? Validators.email(...)!` threw a
  // null-assertion error when both values were valid, so Continue did nothing.
  testWidgets('Seller sign-up: Continue advances with valid name and email', (
    tester,
  ) async {
    await _usePhoneViewport(tester);

    await tester.pumpWidget(
      ProviderScope(child: localizedApp(const SellerSignUpScreen(), theme: buildLightTheme())),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Aline Uwase');
    await tester.enterText(fields.at(1), 'aline@example.com');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Step 2 asks for the password + confirmation.
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Seller sign-up: invalid email is reported, step stays put', (
    tester,
  ) async {
    await _usePhoneViewport(tester);

    await tester.pumpWidget(
      ProviderScope(child: localizedApp(const SellerSignUpScreen(), theme: buildLightTheme())),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Aline Uwase');
    await tester.enterText(fields.at(1), 'not-an-email');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Confirm Password'), findsNothing);
  });
}

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}


