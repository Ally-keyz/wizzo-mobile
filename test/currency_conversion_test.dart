import 'package:flutter_test/flutter_test.dart';

import 'package:wizzo_market/core/currency/currencies.dart';
import 'package:wizzo_market/core/currency/currency_service.dart';

/// The listing form lets a seller type the price in any supported currency and
/// converts it to the base RWF figure the API stores, so these cover the
/// round-trip that conversion depends on.
void main() {
  group('convertToBase', () {
    test('leaves a base RWF amount untouched', () {
      expect(convertToBase(25000, kBaseCurrency, null), 25000);
      expect(convertToBase(25000, kBaseCurrency, const {'USD': 0.0007}), 25000);
    });

    test('divides by the live rate when one is available', () {
      expect(
        convertToBase(20, 'USD', const {'USD': 0.0005}),
        closeTo(40000, 0.001),
      );
    });

    test('falls back to the static snapshot when rates are missing', () {
      expect(
        convertToBase(10, 'USD', null),
        closeTo(10 / kFallbackRates['USD']!, 0.001),
      );
    });

    test('an unknown code never divides by zero', () {
      expect(convertToBase(100, 'ZZZ', const {'ZZZ': 0}), 100);
    });
  });

  group('convertToBase round-trips convertFromBase', () {
    test('a typed amount survives the trip to RWF and back', () {
      for (final def in kCurrencies) {
        final base = convertToBase(17.5, def.code, kFallbackRates);
        expect(
          convertFromBase(base, def.code, kFallbackRates),
          closeTo(17.5, 0.0001),
          reason: 'round trip failed for ${def.code}',
        );
      }
    });
  });
}
