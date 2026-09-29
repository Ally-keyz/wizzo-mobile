import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizzo_market/core/widgets/bottom_nav.dart';

/// The gold Sell circle is painted above the bottom nav bar, so any screen that
/// pins a primary action to the bottom of the shell body must reserve
/// [kSellButtonOverhang] of clearance or the bar covers the button.
void main() {
  test('kSellButtonOverhang matches the Sell circle protrusion', () {
    expect(kSellButtonOverhang, 20);
  });

  testWidgets('Sell circle extends above the bottom nav bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('body')),
          bottomNavigationBar: Builder(
            builder: (context) {
              // Mirror the production bar: 62px tall, circle positioned above.
              return SizedBox(
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: -kSellButtonOverhang,
                            child: Container(
                              key: const Key('sellCircle'),
                              width: 58,
                              height: 58,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final navTop = tester.getTopLeft(find.byType(MaterialApp)).dy;
    expect(navTop, isNotNull);

    final circleTop = tester.getTopLeft(find.byKey(const Key('sellCircle'))).dy;
    final barTop = tester.getTopLeft(find.byType(SizedBox).first).dy;

    // The circle must start above the bar it belongs to, by the overhang.
    expect(barTop - circleTop, kSellButtonOverhang);
  });

  testWidgets('bottom CTA clears the Sell circle when padding is applied',
      (tester) async {
    const barHeight = 62.0;

    Future<double> measureBottomGap({required bool withClearance}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                Container(
                  key: const Key('ctaBar'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    withClearance ? 10 + kSellButtonOverhang : 10,
                  ),
                  child: const SizedBox(
                    key: Key('ctaButton'),
                    height: 52,
                    child: Center(child: Text('CTA')),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              key: const Key('navBar'),
              height: barHeight,
              color: Colors.black,
            ),
          ),
        ),
      );

      // Distance from the bottom of the actual button to the top of the nav bar.
      final ctaBottom =
          tester.getBottomLeft(find.byKey(const Key('ctaButton'))).dy;
      final barTop = tester.getTopLeft(find.byKey(const Key('navBar'))).dy;
      return barTop - ctaBottom;
    }

    // Without clearance the button sits inside the Sell circle's 20px band.
    final without = await measureBottomGap(withClearance: false);
    expect(without, lessThan(kSellButtonOverhang));

    // With clearance the button bottom clears the circle entirely.
    final with_ = await measureBottomGap(withClearance: true);
    expect(with_, greaterThanOrEqualTo(kSellButtonOverhang));
  });
}
