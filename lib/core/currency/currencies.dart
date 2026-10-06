/// Currency definitions mirroring the web frontend's `currencies.ts`.
///
/// The app's base unit is RWF — every numeric price from the API is treated
/// as Rwandan Francs and converted to the display currency client-side.
class CurrencyDef {
  const CurrencyDef({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.flagCode,
  });

  /// ISO 4217 code, e.g. `USD`.
  final String code;

  /// English display name, e.g. `US Dollar`.
  final String name;

  /// Fallback symbol, e.g. `$`.
  final String symbol;

  /// Number of decimals used when formatting (0 for most African currencies).
  final int decimals;

  /// ISO 3166-1 alpha-2 country code whose flag represents this currency
  /// (used with [FlagIcon] to show flags instead of code text).
  final String flagCode;
}

const String kBaseCurrency = 'RWF';

const List<CurrencyDef> kCurrencies = [
  CurrencyDef(code: 'RWF', name: 'Rwandan Franc', symbol: 'FRw', decimals: 0, flagCode: 'rw'),
  CurrencyDef(code: 'USD', name: 'US Dollar', symbol: r'$', decimals: 2, flagCode: 'us'),
  CurrencyDef(code: 'EUR', name: 'Euro', symbol: '€', decimals: 2, flagCode: 'eu'),
  CurrencyDef(code: 'GBP', name: 'British Pound', symbol: '£', decimals: 2, flagCode: 'gb'),
  CurrencyDef(code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh', decimals: 0, flagCode: 'ke'),
  CurrencyDef(code: 'UGX', name: 'Ugandan Shilling', symbol: 'USh', decimals: 0, flagCode: 'ug'),
  CurrencyDef(code: 'TZS', name: 'Tanzanian Shilling', symbol: 'TSh', decimals: 0, flagCode: 'tz'),
  CurrencyDef(code: 'BIF', name: 'Burundian Franc', symbol: 'FBu', decimals: 0, flagCode: 'bi'),
  CurrencyDef(code: 'NGN', name: 'Nigerian Naira', symbol: '₦', decimals: 0, flagCode: 'ng'),
  CurrencyDef(code: 'ZAR', name: 'South African Rand', symbol: 'R', decimals: 2, flagCode: 'za'),
  CurrencyDef(code: 'GHS', name: 'Ghanaian Cedi', symbol: 'GH₵', decimals: 2, flagCode: 'gh'),
  CurrencyDef(code: 'XOF', name: 'West African CFA Franc', symbol: 'CFA', decimals: 0, flagCode: 'ci'),
  CurrencyDef(code: 'XAF', name: 'Central African CFA Franc', symbol: 'FCFA', decimals: 0, flagCode: 'cm'),
  CurrencyDef(code: 'ETB', name: 'Ethiopian Birr', symbol: 'Br', decimals: 2, flagCode: 'et'),
  CurrencyDef(code: 'CAD', name: 'Canadian Dollar', symbol: r'CA$', decimals: 2, flagCode: 'ca'),
  CurrencyDef(code: 'AUD', name: 'Australian Dollar', symbol: r'A$', decimals: 2, flagCode: 'au'),
  CurrencyDef(code: 'JPY', name: 'Japanese Yen', symbol: '¥', decimals: 0, flagCode: 'jp'),
  CurrencyDef(code: 'CNY', name: 'Chinese Yuan', symbol: 'CN¥', decimals: 2, flagCode: 'cn'),
  CurrencyDef(code: 'INR', name: 'Indian Rupee', symbol: '₹', decimals: 2, flagCode: 'in'),
  CurrencyDef(code: 'AED', name: 'UAE Dirham', symbol: 'AED', decimals: 2, flagCode: 'ae'),
  CurrencyDef(code: 'SAR', name: 'Saudi Riyal', symbol: 'SR', decimals: 2, flagCode: 'sa'),
  CurrencyDef(code: 'QAR', name: 'Qatari Riyal', symbol: 'QR', decimals: 2, flagCode: 'qa'),
  CurrencyDef(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', decimals: 2, flagCode: 'ch'),
  CurrencyDef(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', decimals: 2, flagCode: 'se'),
  CurrencyDef(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', decimals: 2, flagCode: 'no'),
  CurrencyDef(code: 'DKK', name: 'Danish Krone', symbol: 'kr', decimals: 2, flagCode: 'dk'),
  CurrencyDef(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', decimals: 2, flagCode: 'pl'),
  CurrencyDef(code: 'TRY', name: 'Turkish Lira', symbol: '₺', decimals: 2, flagCode: 'tr'),
  CurrencyDef(code: 'BRL', name: 'Brazilian Real', symbol: r'R$', decimals: 2, flagCode: 'br'),
  CurrencyDef(code: 'MXN', name: 'Mexican Peso', symbol: r'MX$', decimals: 2, flagCode: 'mx'),
  CurrencyDef(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', decimals: 2, flagCode: 'eg'),
  CurrencyDef(code: 'MAD', name: 'Moroccan Dirham', symbol: 'DH', decimals: 2, flagCode: 'ma'),
];

/// Returns the [CurrencyDef] for a code, defaulting to USD when unknown.
CurrencyDef currencyDef(String code) {
  for (final c in kCurrencies) {
    if (c.code == code) return c;
  }
  return kCurrencies[1];
}

/// Whether [code] is one of the supported currencies.
bool isSupportedCurrency(Object? code) {
  if (code is! String) return false;
  return kCurrencies.any((c) => c.code == code);
}

