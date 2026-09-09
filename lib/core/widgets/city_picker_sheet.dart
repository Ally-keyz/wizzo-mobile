import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../geocoding/place_search_service.dart';

/// Modal bottom sheet that lets the user pick a city anywhere in the world.
///
/// Mirrors the web frontend: free-text autocomplete via Photon/Nominatim,
/// debounced as the user types. Returns the chosen place's display label
/// ("City, Country"), or null if dismissed without picking.
Future<String?> showCityPicker(BuildContext context, String? currentCity) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _CityPickerSheet(currentCity: currentCity),
  );
}

class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet({this.currentCity});

  final String? currentCity;

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  final TextEditingController _search = TextEditingController();
  final PlaceSearchService _places = PlaceSearchService();
  Timer? _debounce;

  List<PlaceSuggestion> _results = const [];
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String value) async {
    final trimmed = value.trim();
    setState(() => _query = trimmed);
    _debounce?.cancel();

    if (trimmed.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    final token = ++_searchToken;
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await _places.searchPlaces(trimmed);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  int _searchToken = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = widget.currentCity;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('city.chooseCity'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              current == null || current.isEmpty
                  ? context.tr('city.helper')
                  : context.tr(
                      'city.currentlyBrowsing',
                      namedArgs: {'city': current},
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('city.searchWorldwide'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (value) => _onQueryChanged(value.trim()),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _query.length < 2
                  ? _hintList(theme, scheme)
                  : _results.isEmpty
                  ? (_searching
                        ? _loadingList(theme, scheme)
                        : _emptyList(theme, scheme))
                  : ListView.separated(
                      shrinkWrap: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: scheme.outlineVariant),
                      itemBuilder: (context, i) {
                        final place = _results[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            place.primary,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: place.secondary.isEmpty
                              ? null
                              : Text(
                                  place.secondary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                          leading: const Icon(Icons.location_city, size: 20),
                          onTap: () =>
                              Navigator.of(context).pop(place.displayLabel),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintList(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.travel_explore,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('city.searchWorldwideHint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyList(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          context.tr('city.noCitiesFound'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _loadingList(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('city.searchingCities'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
