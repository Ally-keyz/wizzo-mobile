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
    defaultValue: 'https://wizzo-backend-3.onrender.com/api/v1',
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
  /// SECURITY: these are rotated build-time values, NOT committed. Supply them
  /// when building the app:
  ///   flutter build apk --release \
  ///     --dart-define=GOOGLE_ANDROID_CLIENT_ID=... \
  ///     --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  ///
  /// The Android client must be registered for package `app.wizzo.wizzo_market`
  /// with the signing key's SHA-1. The server client must match the backend's
  /// GOOGLE_CLIENT_ID so `/auth/google` accepts the tokens the app produces.
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String currencyCode = 'RWF';
  static const String webUrl = 'https://wizzomarketplace.com';
  static const String supportEmail = 'support@wizzo.com';
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
