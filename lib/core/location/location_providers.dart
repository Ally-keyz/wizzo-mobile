import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_prefs.dart';
import '../utils/geo.dart';
import 'location_service.dart';

/// Device location detector (permission prompt + GPS + reverse geocode).
final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

/// The last device coordinates we detected, persisted across launches.
///
/// Null until the user grants location access (or when running on a device
/// without a fix). Consumers should fall back to [Geo.fallback] (Kigali).
class SavedCoordsController extends Notifier<NumPoint?> {
  @override
  NumPoint? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final coords = await AppPrefs.lastCoords();
    if (coords != null) {
      state = NumPoint(lat: coords.$1, lng: coords.$2);
    }
  }

  Future<void> set(NumPoint point) async {
    state = point;
    await AppPrefs.setLastCoords(point.lat, point.lng);
  }
}

final savedCoordsProvider = NotifierProvider<SavedCoordsController, NumPoint?>(
  SavedCoordsController.new,
);
