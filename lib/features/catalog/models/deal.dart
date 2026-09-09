import '../../../core/utils/formatters.dart';
import 'product.dart';

enum DealType { flash, today, limited, clearance }

class Deal {
  const Deal({
    required this.id,
    required this.title,
    required this.type,
    this.subtitle,
    this.imageUrl,
    this.bannerUrl,
    this.endsAt,
    this.color,
    this.discountPercent,
    this.productCount,
    this.products = const [],
  });

  final String id;
  final String title;
  final DealType type;
  final String? subtitle;
  final String? imageUrl;
  final String? bannerUrl;
  final DateTime? endsAt;
  final int? color;
  final int? discountPercent;
  final int? productCount;
  final List<Product> products;

  String get routeSegment => switch (type) {
        DealType.flash => 'flash-sale',
        DealType.today => 'todays-deals',
        DealType.limited => 'limited-offers',
        DealType.clearance => 'clearance',
      };

  factory Deal.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid deal payload');
    final typeRaw = json['type']?.toString() ?? '';
    final type = typeRaw.contains('flash')
        ? DealType.flash
        : typeRaw.contains('today')
            ? DealType.today
            : typeRaw.contains('limited')
                ? DealType.limited
                : DealType.clearance;

    return Deal(
      id: json['id']?.toString() ?? typeRaw,
      type: type,
      title: resolveString(json['title'], fallback: 'Deal'),
      subtitle: _nullString(json['subtitle'] ?? json['description']),
      imageUrl: _nullString(json['image'] ?? json['imageUrl'] ?? json['bannerUrl']),
      bannerUrl: _nullString(json['banner'] ?? json['bannerImage'] ?? json['bannerUrl']),
      endsAt: tryParseDate(json['endsAt'] ?? json['expiresAt']),
      color: (json['accentColor'] as num?)?.toInt(),
      discountPercent: (json['discountPercent'] as num?)?.toInt(),
      productCount: (json['productCount'] as num?)?.toInt(),
      products: json['products'] is List
          ? _parseProducts(json['products'] as List)
          : const [],
    );
  }

  static List<Product> _parseProducts(List list) => list
      .whereType<Map>()
      .map((e) => Product.fromApi(e))
      .where((p) => p.id.isNotEmpty)
      .toList();

  static String? _nullString(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}