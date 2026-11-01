/// Central app configuration. All brand copy, endpoints and defaults live
/// here so a single file mirrors the web app's `src/config/site.ts`.
class AppConfig {
  AppConfig._();

  static const String appName = 'Wizzo Market';
  static const String appShortName = 'WIZZO';
  static const String appFullName = 'Wizzo Marketplace';
  static const String tagline = 'Buy. Sell. Connect.';
  static const String positioning = 'Your trusted marketplace in East Africa';

  /// Override at build time with `--dart-define=API_BASE_URL=...`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.wizzomarketplace.com/api/v1',
  );

  /// MapTiler raster tiles (realistic street/satellite maps). Leave empty to
  /// fall back to CARTO light/dark tiles.
  ///
  /// The key is a client-side public key (like the Stripe publishable key
  /// below) — it must ship inside the app — and is restricted on the MapTiler
  /// dashboard to the User-Agent substring `wizzo` (the map requests send
  /// `flutter_map (app.wizzo.wizzo_market)`). It can still be overridden at
  /// build time with `--dart-define=MAPTILER_KEY=...`.
  ///
  /// Style ids you can try: streets-v2, basic-v2, hybrid, satellite,
  /// streets-v2-dark, dataviz-dark, outdoor-v2, topo-v2.
  static const String mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'hTz3U55btgygUtQVsRAC',
  );
  static const String mapTilerLightStyle = String.fromEnvironment(
    'MAPTILER_LIGHT_STYLE',
    defaultValue: 'streets-v2',
  );
  static const String mapTilerDarkStyle = String.fromEnvironment(
    'MAPTILER_DARK_STYLE',
    defaultValue: 'streets-v2-dark',
  );

  /// Default region context (Kigali, Rwanda).
  static const String defaultCity = 'Kigali';
  static const String defaultCountry = 'Rwanda';
  static const double defaultLatitude = -1.9441;
  static const double defaultLongitude = 30.0619;

  static const String currencyCode = 'RWF';
  static const String webUrl = 'https://wizzomarketplace.com';
  static const String supportEmail = 'support@wizzo.com';

  /// Stripe publishable key (public by design). This is the LIVE key shared
  /// with the web storefront; the production API returns the same key in its
  /// payment-intent responses, so this only acts as a fallback. Override with
  /// `--dart-define=STRIPE_PUBLISHABLE_KEY=...` when testing against staging.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_live_51UE1Yq1s5alI3joSctpI76PQpyve0sopNbHMBgpBiVChgAST4ZFh94Xjbm7yx670X8gMNYbfuc61fUuLuENScOHE00dTCmnA3N',
  );

  /// Apple Pay merchant identifier (iOS only). Apple Pay is presented through
  /// Stripe's native wallet sheet and needs this merchant id (created in the
  /// Apple Developer portal and added to the Stripe dashboard) to work.
  /// Override with `--dart-define=APPLE_PAY_MERCHANT_ID=merchant.com.example`.
  static const String applePayMerchantId = String.fromEnvironment(
    'APPLE_PAY_MERCHANT_ID',
    defaultValue: 'merchant.com.wizzomarketplace',
  );

  /// ISO-3166 country of the Stripe account that owns the publishable key.
  /// Apple Pay / Google Pay reject a mismatch, so this must match the account
  /// (the web app uses `VITE_STRIPE_MERCHANT_COUNTRY=DE`), not the buyer.
  static const String stripeMerchantCountry = String.fromEnvironment(
    'STRIPE_MERCHANT_COUNTRY',
    defaultValue: 'DE',
  );

  /// Whether the baked-in Stripe key is a test key. Drives Google Pay's
  /// `testEnv` flag instead of `kReleaseMode`, because a release build can
  /// still be pointed at a test key via `--dart-define`.
  static bool get stripeTestMode => stripePublishableKey.startsWith('pk_test_');

  /// Upper bound for API calls. Kept generous because the free-tier Render
  /// hosting sleeps after idle and can take 30-60s to cold start.
  static const int requestTimeoutSeconds = 90;

  /// The default set of trust badge rows used across screens.
  static const List<(String, String)> trustRowBuyer = [
    ('Verified Sellers', 'Only legitimate, reviewed sellers'),
    ('Secure Payments', 'Pay direct to the seller'),
    ('Local Pickup', 'Meet and inspect your item'),
    ('24/7 Support', "We're always here"),
  ];
}
