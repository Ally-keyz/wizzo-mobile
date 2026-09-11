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
  /// Get a free key at https://cloud.maptiler.com (create account -> keys).
  /// Style ids you can try: streets-v2, basic-v2, hybrid, satellite,
  /// dark, light, outdoor-v2.
  static const String mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );
  static const String mapTilerLightStyle = String.fromEnvironment(
    'MAPTILER_LIGHT_STYLE',
    defaultValue: 'streets-v2',
  );
  static const String mapTilerDarkStyle = String.fromEnvironment(
    'MAPTILER_DARK_STYLE',
    defaultValue: 'dark',
  );

  /// Default region context (Kigali, Rwanda).
  static const String defaultCity = 'Kigali';
  static const String defaultCountry = 'Rwanda';
  static const double defaultLatitude = -1.9441;
  static const double defaultLongitude = 30.0619;

  /// Google OAuth client IDs for Google Sign-In (Google Cloud Console).
  ///
  /// These are public OAuth client identifiers (they must ship inside the app,
  /// exactly like google-services.json), NOT secrets — so they are compiled in
  /// below to guarantee Google Sign-In works in every build. They can still be
  /// overridden at build time if the credentials are ever rotated:
  ///   flutter build apk --release \
  ///     --dart-define=GOOGLE_ANDROID_CLIENT_ID=... \
  ///     --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  ///
  /// On Android google_sign_in ignores `clientId` (the app is identified by
  /// package name + signing-key SHA-1) and uses `serverClientId` to request an
  /// ID token. `serverClientId` MUST be the OAuth Web client id so the tokens
  /// are issued for the audience the backend's `/auth/google` verifies.
  ///
  /// The Android client must be registered for package `app.wizzo.wizzo_market`
  /// with the signing key's SHA-1. The server client must match the backend's
  /// GOOGLE_CLIENT_ID so `/auth/google` accepts the tokens the app produces.
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '953421637514-ohh0fj36g97d9lg7s7ogf18ricb0bvil.apps.googleusercontent.com',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '953421637514-1p9054rkqo9t5onpi0j8tbab0jmvq75l.apps.googleusercontent.com',
  );

  static const String currencyCode = 'RWF';
  static const String webUrl = 'https://wizzomarketplace.com';
  static const String supportEmail = 'support@wizzo.com';

  /// Stripe publishable key for Google Pay on mobile (test mode).
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51UE1ZQ1HGKUHOr34tixbSjZVi5MCBHbdhJLHKeaT2ntl55iIAnmklzBtEU3XLkxaJmgRH42qTipbnQANqb13kWZk00kFInznQI',
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
