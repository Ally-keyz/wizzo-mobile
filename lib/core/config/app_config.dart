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

  /// Stripe publishable key for Google Pay on mobile (test mode).
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51UE1ZQ1HGKUHOr34tixbSjZVi5MCBHbdhJLHKeaT2ntl55iIAnmklzBtEU3XLkxaJmgRH42qTipbnQANqb13kWZk00kFInznQI',
  );

  /// Apple Pay merchant identifier (iOS only). Apple Pay is only attached to
  /// the Stripe PaymentSheet when this is set — passing an Apple Pay config
  /// without a merchant identifier trips flutter_stripe's assertion.
  /// Configure with `--dart-define=APPLE_PAY_MERCHANT_ID=merchant.com.example`.
  static const String applePayMerchantId = String.fromEnvironment(
    'APPLE_PAY_MERCHANT_ID',
  );
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
