import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/core/theme/app_theme.dart';
import 'package:wizzo_market/core/widgets/w_widgets.dart';

void main() {
  const steps = [
    'Placed',
    'Confirmed',
    'Processing',
    'Preparing',
    'Ready for Pickup',
    'Completed',
  ];

  Future<void> pump(WidgetTester tester, {required int current}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 294,
              child: WStepIndicator(steps: steps, current: current),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long step labels never overflow a narrow card', (tester) async {
    await pump(tester, current: 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-steps-done grid renders and fits', (tester) async {
    await pump(tester, current: steps.length);
    expect(tester.takeException(), isNull);
  });
}
