import 'package:flutter/material.dart';

import '../../../core/utils/geo.dart';
import '../../../core/utils/formatters.dart';

class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.name,
    required this.slug,
    this.children = const [],
    this.icon,
  });

  final String id;
  final String name;
  final String slug;
  final List<CategoryNode> children;
  final IconData? icon;

  static List<CategoryNode> parseTree(dynamic data) {
    if (data is! List) return const [];
    return data.map(_parseNode).toList();
  }

  static CategoryNode _parseNode(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CategoryNode(id: '', name: '', slug: '');
    }
    final childrenRaw = json['children'] ?? json['subcategories'];
    final children =
        childrenRaw is List ? childrenRaw.map(_parseNode).toList() : const <CategoryNode>[];

    final id = json['id']?.toString() ??
        json['_id']?.toString() ??
        json['slug']?.toString() ??
        '';
    final name = resolveString(json['name'], fallback: 'Category');
    final slug = json['slug']?.toString() ?? '';

    return CategoryNode(
      id: id,
      name: name,
      slug: slug,
      children: children,
      icon: iconForCategory(slug),
    );
  }
}

/// Maps a category slug to a Material icon for the categories grid.
IconData? iconForCategory(String slug) {
  final s = slug.toLowerCase();
  const tokens = <String, IconData>{
    'fashion': Icons.checkroom,
    'electronics': Icons.devices,
    'phones': Icons.smartphone,
    'phones-tablets': Icons.smartphone,
    'home-living': Icons.chair,
    'home-appliances': Icons.kitchen,
    'beauty-health': Icons.spa,
    'beauty': Icons.spa,
    'supermarket': Icons.local_grocery_store,
    'vehicles': Icons.directions_car,
    'agriculture': Icons.agriculture,
    'sports-outdoor': Icons.sports_soccer,
    'sports': Icons.sports_soccer,
    'toys': Icons.toys,
    'toys-babies': Icons.child_care,
    'baby': Icons.child_care,
    'services': Icons.handyman,
    'business-industry': Icons.business,
    'books': Icons.menu_book,
    'books-media': Icons.menu_book,
    'education': Icons.school,
    'pets': Icons.pets,
    'office': Icons.edit,
    'travel': Icons.flight,
    'language': Icons.translate,
    'import-export': Icons.swap_horiz,
    'automotive': Icons.car_repair,
    'realestate': Icons.real_estate_agent,
    'real-estate': Icons.real_estate_agent,
    'furniture': Icons.weekend,
    'sewing': Icons.cut,
    'rentals': Icons.key,
    'rental': Icons.key,
  };
  return tokens[s];
}

class Seller {
  const Seller({
    required this.id,
    required this.storeName,
    required this.storeSlug,
    this.userId,
    this.logoUrl,
    this.coverUrl,
    this.aboutStore,
    this.country,
    this.city,
    this.district,
    this.verified = false,
    this.ratingAvg,
    this.ratingCount,
    this.productsCount,
    this.followersCount,
    this.latitude,
    this.longitude,
    this.lastSeenAt,
    this.isFollowing = false,
    this.responseRate,
    this.tags = const [],
    this.categoryCount = 0,
  });

  final String id;
  final String storeName;
  final String storeSlug;
  final String? userId;
  final String? logoUrl;
  final String? coverUrl;
  final String? aboutStore;
  final String? country;
  final String? city;
  final String? district;
  final bool verified;
  final double? ratingAvg;
  final int? ratingCount;
  final int? productsCount;
  final int? followersCount;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeenAt;
  final bool isFollowing;
  final double? responseRate;
  final List<String> tags;
  final int categoryCount;

  bool get hasLocation => latitude != null && longitude != null;
  String get locationLabel {
    final parts = [city, district].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  double? distanceTo(NumPoint point) {
    if (!hasLocation) return null;
    return Geo.distanceKm(latitude!, longitude!, point.lat, point.lng);
  }

  factory Seller.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid seller payload');
    final loc = json['location'];
    final rawUserId = json['userId'];
    num? lat;
    num? lng;
    if (loc is Map) {
      if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        final coords = loc['coordinates'] as List;
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      } else {
        lat = (loc['lat'] ?? loc['latitude'] as num?)?.toDouble();
        lng = (loc['lng'] ?? loc['longitude'] as num?)?.toDouble();
      }
    } else {
      lat = (json['latitude'] as num?)?.toDouble();
      lng = (json['longitude'] as num?)?.toDouble();
    }

    return Seller(
      id: json['id']?.toString() ?? json['sellerId']?.toString() ?? '',
      storeName: resolveString(json['storeName'] ?? json['name'], fallback: 'Seller'),
      storeSlug: json['storeSlug']?.toString() ?? json['slug']?.toString() ?? '',
      userId: rawUserId is Map
          ? (rawUserId['id'] ?? rawUserId['_id'])?.toString()
          : rawUserId?.toString(),
      logoUrl: _stripOrNull(json['logoUrl'] ?? json['avatar']),
      coverUrl: _stripOrNull(json['coverUrl']),
      aboutStore: resolveString(json['aboutStore'] ?? json['description']),
      country: resolveString(json['country']),
      city: resolveString(json['city'] ?? json['locationLabel']),
      district: resolveString(json['district']),
      verified: json['verifiedBadge'] == true || json['verified'] == true,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      productsCount: (json['productsCount'] as num?)?.toInt(),
      followersCount: (json['followersCount'] as num?)?.toInt(),
      latitude: lat?.toDouble(),
      longitude: lng?.toDouble(),
      lastSeenAt: tryParseDate(json['lastSeenAt'] ?? json['lastActiveAt']),
      isFollowing: json['isFollowing'] == true,
      responseRate: (json['responseRate'] as num?)?.toDouble(),
      tags: json['tags'] is List ? json['tags'].map((e) => e.toString()).toList() : const [],
      categoryCount: (json['categoryCount'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _stripOrNull(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}