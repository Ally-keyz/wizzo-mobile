import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'currencies.dart';

/// Keyless public rates API (base = RWF), same as the web frontend.
const String kRatesUrl = 'https://open.er-api.com/v6/latest/RWF';

/// Static snapshot used when the rates API is unreachable (RWF → X, Aug 2026).
const Map<String, double> kFallbackRates = {
  'USD': 0.000683,
  'EUR': 0.000581,
  'GBP': 0.0005,
  'KES': 0.0878,
  'UGX': 2.5,
  'TZS': 1.75,
  'BIF': 2.0,
  'NGN': 1.05,
  'ZAR': 0.0124,
  'GHS': 0.0105,
  'XOF': 0.381,
  'XAF': 0.381,
  'ETB': 0.087,
  'CAD': 0.00093,
  'AUD': 0.00102,
  'JPY': 0.101,
  'CNY': 0.00487,
  'INR': 0.0588,
  'AED': 0.00251,
  'SAR': 0.00256,
  'QAR': 0.00248,
  'CHF': 0.00054,
  'SEK': 0.00706,
  'NOK': 0.00703,
  'DKK': 0.00433,
  'PLN': 0.00247,
  'TRY': 0.0283,
  'BRL': 0.00372,
  'MXN': 0.0125,
  'EGP': 0.0333,
  'MAD': 0.00676,
};

const Map<String, String> _headers = {
  'User-Agent': 'WizzoMobile/1.0 (https://wizzo.market)',
  'Accept': 'application/json',
};

/// Fetches live RWF→X exchange rates. Returns null on any failure.
Future<Map<String, double>?> fetchLatestRates() async {
  try {
    final res = await http
        .get(Uri.parse(kRatesUrl), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! Map || data['result'] != 'success') return null;
    final rates = data['rates'];
    if (rates is! Map) return null;
    final out = <String, double>{};
    rates.forEach((key, value) {
      if (value is num) out['$key'] = value.toDouble();
    });
    if (!out.containsKey(kBaseCurrency)) return null;
    return out;
  } catch (_) {
    return null;
  }
}

/// Converts a base-RWF amount to [code]. Falls back to static rates.
double convertFromBase(num amount, String code, Map<String, double>? rates) {
  if (code == kBaseCurrency) return amount.toDouble();
  final rate = rates?[code] ?? kFallbackRates[code] ?? 1;
  return amount * rate;
}

/// Formats a base-RWF amount in the selected currency, mirroring the web's
/// `formatFromBase`: `$1,234.56`, `RWF 1,234,567`, `KSh 1,234,567`, ...
String formatFromBase(num? amount, String code, Map<String, double>? rates) {
  final def = currencyDef(code);
  final value = convertFromBase(amount ?? 0, code, rates);
  final safe = value < 0 ? 0 : value;
  try {
    return NumberFormat.simpleCurrency(
      locale: 'en_US',
      name: code,
      decimalDigits: def.decimals,
    ).format(safe);
  } catch (_) {
    final grouped = NumberFormat.decimalPattern('en_US').format(safe);
    return '${def.symbol} $grouped';
  }
}
