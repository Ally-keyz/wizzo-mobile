import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A geocoded place suggestion returned by [PlaceSearchService.searchPlaces].
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.primary,
    required this.secondary,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  /// Main display name (place / city).
  final String primary;

  /// Region + country context line.
  final String secondary;

  final String city;
  final String country;
  final double latitude;
  final double longitude;

  /// "City, Country" label used when the user picks this place.
  String get displayLabel => country.isEmpty ? city : '$city, $country';
}

/// Forward-geocodes free text to worldwide place suggestions (autocomplete).
///
/// Mirrors the web frontend's `geoService`: Photon (keyless) first, with an
/// OpenStreetMap Nominatim fallback when Photon returns nothing.
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  static const Map<String, String> _headers = {
    // Photon/Nominatim reject requests whose User-Agent doesn't look like a
    // browser (Dart's default "Dart/x.y" gets a 403).
    'User-Agent': 'WizzoMobile/1.0 (https://wizzo.market)',
    'Accept': 'application/json',
  };

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final collected = <PlaceSuggestion>[];
    try {
      final res = await _client
          .get(
            Uri.parse(
              'https://photon.komoot.io/api/?'
              'q=${Uri.encodeQueryComponent(trimmed)}&limit=6',
            ),
            headers: _headers,
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final features = data['features'] as List? ?? const [];
        for (final f in features.cast<Map<String, dynamic>>()) {
          final p = (f['properties'] as Map<String, dynamic>?) ?? const {};
          final g = (f['geometry'] as Map<String, dynamic>?) ?? const {};
          final coords = (g['coordinates'] as List?) ?? const [];
          final name = (p['name'] as String?) ?? '';
          final city =
              _pick(p, 'city') ??
              _pick(p, 'town') ??
              _pick(p, 'village') ??
              _pick(p, 'county') ??
              _pick(p, 'state') ??
              '';
          final primary = name.isNotEmpty ? name : city;
          if (primary.isEmpty) continue;
          final state = _pick(p, 'state') ?? '';
          final country = _pick(p, 'country') ?? '';
          collected.add(
            PlaceSuggestion(
              primary: primary,
              secondary: [
                if (state.isNotEmpty) state,
                if (country.isNotEmpty) country,
              ].join(', '),
              city: city.isNotEmpty ? city : primary,
              country: country,
              latitude: coords.isNotEmpty ? (coords[1] as num).toDouble() : 0,
              longitude: coords.isNotEmpty ? (coords[0] as num).toDouble() : 0,
            ),
          );
        }
      }
    } catch (_) {
      // Photon failed; fall through to Nominatim.
    }

    if (collected.isEmpty) {
      try {
        final res = await _client
            .get(
              Uri.parse(
                'https://nominatim.openstreetmap.org/search?'
                'format=jsonv2&addressdetails=1&limit=6&accept-language=en&'
                'q=${Uri.encodeQueryComponent(trimmed)}',
              ),
              headers: _headers,
            )
            .timeout(_timeout);
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
          for (final r in data.cast<Map<String, dynamic>>()) {
            final a = (r['address'] as Map<String, dynamic>?) ?? const {};
            final city =
                (a['city'] ??
                        a['town'] ??
                        a['village'] ??
                        a['county'] ??
                        a['state'])
                    .toString();
            final primary = (r['name'] as String? ?? '').isNotEmpty
                ? r['name'] as String
                : city;
            if (primary.isEmpty) continue;
            collected.add(
              PlaceSuggestion(
                primary: primary,
                secondary: [
                  if ((a['state'] as String?)?.isNotEmpty ?? false) a['state']!,
                  if ((a['country'] as String?)?.isNotEmpty ?? false)
                    a['country']!,
                ].join(', '),
                city: city.isNotEmpty ? city : primary,
                country: (a['country'] as String?) ?? '',
                latitude: double.tryParse((r['lat'] as String?) ?? '') ?? 0,
                longitude: double.tryParse((r['lon'] as String?) ?? '') ?? 0,
              ),
            );
          }
        }
      } catch (_) {
        // Both geocoders failed — return whatever (possibly empty) we have.
      }
    }

    collected.sort(_rank(trimmed));

    final seen = <String>{};
    final result = <PlaceSuggestion>[];
    for (final s in collected) {
      if (seen.add('${s.primary}|${s.secondary}')) result.add(s);
    }
    return result.take(6).toList();
  }

  /// Prioritises suggestions whose name or city matches the query, so the
  /// exact city (e.g. "Paris") ranks above its wider region ("Île-de-France").
  static int Function(PlaceSuggestion, PlaceSuggestion) _rank(String query) {
    final q = query.toLowerCase();
    int score(PlaceSuggestion s) {
      final name = s.primary.toLowerCase();
      final city = s.city.toLowerCase();
      if (name.startsWith(q) || city.startsWith(q)) return 0;
      if (name.contains(q) || city.contains(q)) return 1;
      return 2;
    }

    return (a, b) => score(a).compareTo(score(b));
  }

  static String? _pick(Map<String, dynamic> map, String key) {
    final v = map[key];
    return v is String && v.isNotEmpty ? v : null;
  }
}
