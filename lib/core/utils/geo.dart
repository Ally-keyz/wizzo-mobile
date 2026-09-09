import 'dart:math';

import '../config/app_config.dart';

class Geo {
  Geo._();

  /// Haversine distance in km between two coordinates.
  static double distanceKm(num lat1, num lng1, num lat2, num lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  static String formatKm(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(1)}km';
  }

  static NumPoint fallback() =>
      NumPoint(lat: AppConfig.defaultLatitude, lng: AppConfig.defaultLongitude);

  static double _rad(num deg) => deg * pi / 180;
}

class NumPoint {
  const NumPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}