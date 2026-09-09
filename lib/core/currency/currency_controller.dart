import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/app_prefs.dart';
import 'currencies.dart';
import 'currency_service.dart';

/// Snapshot of the active display currency and its RWF exchange rates.
@immutable
class CurrencyState {
  const CurrencyState({required this.code, this.rates, this.ratesUpdatedAt});

  /// ISO 4217 display currency code.
  final String code;

  /// RWF → X rates snapshot (null until first fetch).
  final Map<String, double>? rates;

  final DateTime? ratesUpdatedAt;
}

/// Global, app-wide display-currency store.
///
/// Mirrors the web frontend's Zustand `wizzo-currency` store: the choice is
/// persisted, and every price rendered through [formatFromBase] converts
/// instantly. The whole widget tree listens via [ValueListenableBuilder].
class CurrencyController extends ValueNotifier<CurrencyState> {
  CurrencyController() : super(const CurrencyState(code: 'USD'));

  static const _maxAge = Duration(hours: 12);

  bool _hydrated = false;

  /// Loads the persisted currency and refreshes exchange rates once.
  /// Kicks off a non-blocking rates refresh behind the scenes.
  Future<void> init() async {
    if (_hydrated) return;
    _hydrated = true;
    final saved = await AppPrefs.currency();
    if (saved != null) {
      final savedCode = saved['code'];
      final rates = saved['rates'];
      final updatedAt = saved['ratesUpdatedAt'];
      value = CurrencyState(
        code: isSupportedCurrency(savedCode) ? savedCode as String : 'USD',
        rates: rates is Map
            ? rates.map((k, v) => MapEntry('$k', v is num ? v.toDouble() : 0))
            : null,
        ratesUpdatedAt: updatedAt is num
            ? DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt())
            : null,
      );
    }
    unawaited(refreshRatesIfStale());
  }

  /// Selects a new display currency and persists it.
  Future<void> setCurrency(String code) async {
    final c = isSupportedCurrency(code) ? code : 'USD';
    final state = value;
    value = CurrencyState(
      code: c,
      rates: state.rates,
      ratesUpdatedAt: state.ratesUpdatedAt,
    );
    await AppPrefs.setCurrency(c, state.rates, state.ratesUpdatedAt);
  }

  /// Refetches rates only when the cached snapshot is older than 12h.
  /// Never throws; falls back to the static snapshot when offline.
  Future<void> refreshRatesIfStale() async {
    final state = value;
    final stale =
        state.ratesUpdatedAt == null ||
        DateTime.now().difference(state.ratesUpdatedAt!) > _maxAge;
    if (!stale) return;
    final rates = await fetchLatestRates();
    if (rates != null) {
      final updatedAt = DateTime.now();
      value = CurrencyState(
        code: state.code,
        rates: rates,
        ratesUpdatedAt: updatedAt,
      );
      await AppPrefs.setCurrency(state.code, rates, updatedAt);
    } else if (state.rates == null) {
      value = CurrencyState(code: state.code);
      await AppPrefs.setCurrency(state.code, null, null);
    }
  }
}

/// Singleton used across the app (mirrors the Zustand store singleton).
final CurrencyController currencyController = CurrencyController();
