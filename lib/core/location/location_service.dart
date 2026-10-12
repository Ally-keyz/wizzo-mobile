import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../geocoding/place_search_service.dart';

/// A resolved device location: coordinates plus the nearest city label.
class DetectedLocation {
  const DetectedLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;

  /// "City, Country" label used for the city bar and address prefill.
  String get label {
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }
}

/// Why a location lookup could not complete.
enum LocationFailure {
  /// Location services (GPS) are turned off at the OS level.
  serviceDisabled,

  /// The user dismissed the OS permission prompt.
  denied,

  /// The permission was permanently denied — the user must enable it in
  /// system settings.
  deniedForever,

  /// The fix or reverse geocode failed for another reason (timeout, network).
  unavailable,
}

/// Outcome of [LocationService.detect].
class LocationResult {
  const LocationResult.success(this.location) : failure = null;
  const LocationResult.failed(this.failure) : location = null;

  final DetectedLocation? location;
  final LocationFailure? failure;

  bool get ok => location != null;
}

/// Wraps the device GPS + reverse geocoding in one call. Requesting permission
/// here triggers the native OS prompt ("Allow Wizzo to use your location?").
class LocationService {
  LocationService({PlaceSearchService? places})
    : _places = places ?? PlaceSearchService();

  final PlaceSearchService _places;

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 20),
  );

  Future<LocationResult> detect() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationFailure.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }

      // Prefer a cached fix for an instant result, then fall back to a fresh
      // one (a cold GPS fix can take several seconds).
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: _settings,
          );

      final place = await _places.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return LocationResult.success(
        DetectedLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          city: place?.city ?? '',
          country: place?.country ?? '',
        ),
      );
    } catch (_) {
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }
}
