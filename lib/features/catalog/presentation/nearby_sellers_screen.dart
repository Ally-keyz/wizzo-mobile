import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../models/seller.dart';
import '../providers/catalog_providers.dart';

class NearbySellersScreen extends ConsumerStatefulWidget {
  const NearbySellersScreen({super.key});

  @override
  ConsumerState<NearbySellersScreen> createState() =>
      _NearbySellersScreenState();
}

class _NearbySellersScreenState extends ConsumerState<NearbySellersScreen> {
  late final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _listOpen = false;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(nearbySellersProvider, (prev, next) {
      if (next.hasValue) {
        _fitted = false;
        _scheduleFit(next.value ?? const []);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleFit(List<Seller> sellers) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers(sellers));
  }

  void _fitMarkers(List<Seller> sellers) {
    if (!_mapReady || _fitted || sellers.isEmpty) return;
    final withLoc = sellers.where((s) => s.hasLocation).toList();
    if (withLoc.isEmpty) return;
    _fitted = true;
    final coords = withLoc
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: coords,
        padding: const EdgeInsets.all(48),
        maxZoom: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellersAsync = ref.watch(nearbySellersProvider);
    final sellers = sellersAsync.value ?? const <Seller>[];

    return Scaffold(
      body: Stack(
        children: [
          // The map is always the base layer so it stays visible (pre-loaded)
          // even while nearby sellers are still being fetched.
          Positioned.fill(child: _buildMap(sellers)),
          if (sellersAsync.isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Palette.navy.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: Palette.gold,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (sellersAsync.hasError)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _OverlayCard(
                icon: Icons.cloud_off,
                title: context.tr('sellers.loadFailed'),
                subtitle: '${sellersAsync.error}',
                actionLabel: context.tr('common.retry'),
                onAction: () => ref.invalidate(nearbySellersProvider),
              ),
            )
          else if (sellers.isEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _OverlayCard(
                icon: Icons.store_mall_directory_outlined,
                title: context.tr('sellers.noneNearby'),
                subtitle: context.tr('sellers.noneNearbyHint'),
              ),
            )
          else ...[
            if (_listOpen)
              Positioned(
                left: 12,
                right: 12,
                bottom: 78,
                child: _NearbyListSheet(sellers: sellers),
              ),
            Positioned(
              left: 12,
              bottom: 16,
              child: _ListToggleButton(
                count: sellers.length,
                open: _listOpen,
                onTap: () => setState(() => _listOpen = !_listOpen),
              ),
            ),
          ],
          _FloatingHeader(
            title: context.tr('sellers.title'),
            onBack: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<Seller> sellers) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        backgroundColor: dark ? Palette.navy : const Color(0xFFE9E9EE),
        initialCenter: _initialCenter(sellers),
        initialZoom: 12,
        onMapReady: () {
          _mapReady = true;
          _scheduleFit(sellers);
        },
      ),
      children: [
        _buildTileLayer(dark),
        MarkerLayer(
          markers: [
            for (final s in sellers.where((s) => s.hasLocation))
              Marker(
                point: LatLng(s.latitude!, s.longitude!),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showPanel(s),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Palette.gold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.storeName.isEmpty
                          ? '?'
                          : s.storeName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SimpleAttributionWidget(
          source: Text(
            _tileAttribution(),
            style: TextStyle(
              color: dark ? Colors.white70 : Colors.black54,
              fontSize: 10,
            ),
          ),
          backgroundColor: dark
              ? const Color(0xCC0B0E1A)
              : const Color(0xCCFFFFFF),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }

  /// Theme-aware, realistic tiles: MapTiler (streets/dark) when an API key is
  /// configured, otherwise CARTO light/dark as a keyless fallback.
  Widget _buildTileLayer(bool dark) {
    const userAgent = 'app.wizzo.wizzo_market';
    final key = AppConfig.mapTilerKey;
    if (key.isNotEmpty) {
      final style = dark
          ? AppConfig.mapTilerDarkStyle
          : AppConfig.mapTilerLightStyle;
      return TileLayer(
        urlTemplate:
            'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.png?key=$key',
        userAgentPackageName: userAgent,
      );
    }
    return TileLayer(
      urlTemplate:
          'https://basemaps.cartocdn.com/${dark ? 'dark_all' : 'light_all'}/{z}/{x}/{y}.png',
      userAgentPackageName: userAgent,
    );
  }

  String _tileAttribution() {
    if (AppConfig.mapTilerKey.isNotEmpty) {
      return context.tr('sellers.attributionMaptiler');
    }
    return context.tr('sellers.attributionCarto');
  }

  LatLng _initialCenter(List<Seller> sellers) {
    final located = sellers.where((s) => s.hasLocation).toList();
    if (located.isNotEmpty)
      return LatLng(located.first.latitude!, located.first.longitude!);
    return LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
  }

  void _showPanel(Seller s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => _SellerSheet(seller: s),
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xCC0B0E1A), Color(0x000B0E1A)]
                : const [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                _GlassCircleButton(icon: Icons.arrow_back, onTap: onBack),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF20B0E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.gold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Palette.gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dark
              ? const Color(0x330B0E1A)
              : Colors.black.withValues(alpha: 0.20),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: dark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

final nearbySellersProvider = FutureProvider<List<Seller>>((ref) {
  return ref
      .read(catalogRepositoryProvider)
      .nearbySellers(
        lat: AppConfig.defaultLatitude,
        lng: AppConfig.defaultLongitude,
      );
});

class _ListToggleButton extends StatelessWidget {
  const _ListToggleButton({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xF00B0E1A) : const Color(0xFAFFFFFF),
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: Palette.gold,
              ),
              const SizedBox(width: 8),
              Text(
                open
                    ? context.tr('sellers.hideShops')
                    : context.tr(
                        'sellers.shopsNearby',
                        namedArgs: {'count': '$count'},
                      ),
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                open ? Icons.expand_more : Icons.expand_less,
                size: 18,
                color: dark ? Colors.white70 : Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyListSheet extends StatelessWidget {
  const _NearbyListSheet({required this.sellers});

  final List<Seller> sellers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...sellers]..removeWhere((s) => !s.hasLocation);
    sorted.sort((a, b) {
      final da = a.distanceTo(Geo.fallback()) ?? double.infinity;
      final db = b.distanceTo(Geo.fallback()) ?? double.infinity;
      return da.compareTo(db);
    });

    return Container(
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      'sellers.shopsNearby',
                      namedArgs: {'count': '${sorted.length}'},
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final s = sorted[i];
                final distance = s.distanceTo(Geo.fallback());
                return _SellerTile(
                  seller: s,
                  distanceLabel: distance != null
                      ? Geo.formatKm(distance)
                      : null,
                  onTap: () => context.push(
                    '/shop/${s.storeSlug.isNotEmpty ? s.storeSlug : s.id}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({
    required this.seller,
    this.distanceLabel,
    required this.onTap,
  });

  final Seller seller;
  final String? distanceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          seller.storeName.isEmpty
              ? '?'
              : seller.storeName.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Palette.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              seller.storeName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (seller.verified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 14, color: Palette.infoBlue),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (distanceLabel != null) distanceLabel!,
          if (seller.locationLabel.isNotEmpty) seller.locationLabel,
        ].join(' • '),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _SellerSheet extends StatelessWidget {
  const _SellerSheet({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  seller.storeName.isEmpty
                      ? '?'
                      : seller.storeName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Palette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (seller.locationLabel.isNotEmpty)
                      Text(
                        seller.locationLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  '/shop/${seller.storeSlug.isNotEmpty ? seller.storeSlug : seller.id}',
                );
              },
              child: Text(context.tr('sellers.visitShop')),
            ),
          ),
        ],
      ),
    );
  }
}
