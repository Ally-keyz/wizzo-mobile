import '../../../core/utils/formatters.dart';

/// Seller summary nested on products and order groups.
class ProductSeller {
  const ProductSeller({
    this.id,
    this.userId,
    this.storeName,
    this.storeSlug,
    this.logoUrl,
    this.verified = false,
    this.ratingAvg,
    this.responseRate,
    this.online = false,
  });

  final String? id;
  final String? userId;
  final String? storeName;
  final String? storeSlug;
  final String? logoUrl;
  final bool verified;
  final double? ratingAvg;
  final double? responseRate;
  final bool online;

  String get displayName =>
      (storeName != null && storeName!.trim().isNotEmpty) ? storeName! : 'Wizzo Seller';

  factory ProductSeller.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const ProductSeller();
    return ProductSeller(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      userId: json['userId']?.toString() ?? json['_id']?.toString(),
      storeName: json['storeName']?.toString(),
      storeSlug: json['storeSlug']?.toString(),
      logoUrl: _stripOrNull(json['logoUrl']),
      verified: json['verifiedBadge'] == true ||
          json['verified'] == true ||
          json['verificationStatus'] == 'verified',
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      responseRate: (json['responseRate'] as num?)?.toDouble(),
      online: json['online'] == true,
    );
  }

  /// Builds a seller summary from the two populated refs the API returns on
  /// products: `storeId` (storeName/storeSlug/logoUrl/verifiedBadge) and
  /// `sellerId` (fullName/avatarUrl). `legacy` covers API shapes that embed a
  /// ready-made `seller`/`store` object instead.
  factory ProductSeller.fromPopulated({
    Map<String, dynamic>? store,
    Map<String, dynamic>? user,
    dynamic legacy,
  }) {
    if (legacy is Map<String, dynamic>) {
      return ProductSeller.fromApi(legacy);
    }
    if (store == null && user == null) return const ProductSeller();
    final merged = <String, dynamic>{
      ...?store,
      ...?user,
    };
    if (store != null && store['_id'] != null) merged['id'] = store['_id'];
    return ProductSeller.fromApi(merged);
  }

  static String? _stripOrNull(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}

class CategoryRef {
  const CategoryRef({this.id, this.slug, this.name});

  final String? id;
  final String? slug;
  final String? name;

  factory CategoryRef.fromApi(dynamic json) {
    if (json is String) return CategoryRef(id: json);
    if (json is! Map<String, dynamic>) return const CategoryRef();
    return CategoryRef(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      slug: json['slug']?.toString(),
      name: resolveString(json['name']),
    );
  }
}

class ProductSpec {
  const ProductSpec({required this.name, required this.value});

  final String name;
  final String value;

  /// Collapses API `specifications` (single map or array of {name,value}).
  static List<ProductSpec> fromApi(dynamic json) {
    if (json is Map<String, dynamic>) {
      return json.entries
          .map((e) => ProductSpec(name: e.key, value: e.value.toString()))
          .toList();
    }
    if (json is List) {
      return json.map((e) {
        if (e is Map<String, dynamic>) {
          return ProductSpec(
            name: (e['name'] ?? e['key'] ?? '').toString(),
            value: (e['value'] ?? '').toString(),
          );
        }
        return ProductSpec(name: '', value: '');
      }).where((s) => s.name.isNotEmpty).toList();
    }
    return const [];
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.images,
    required this.price,
    this.originalPrice,
    this.discountPercent,
    this.discountEndsAt,
    this.ratingAvg,
    this.ratingCount,
    this.salesCount,
    this.viewsCount,
    this.condition = 'new',
    this.brand,
    this.video,
    this.stock,
    this.description,
    this.category,
    this.subcategory,
    this.seller,
    this.deliveryOptions = const [],
    this.featured = false,
    this.status = 'active',
    this.specs = const [],
    this.sizeOptions = const [],
    this.colorOptions = const [],
    this.sellerLocationLabel,
  });

  final String id;
  final String name;
  final String slug;
  final List<String> images;
  final num price;
  final num? originalPrice;
  final int? discountPercent;
  final DateTime? discountEndsAt;
  final double? ratingAvg;
  final int? ratingCount;
  final int? salesCount;
  final int? viewsCount;
  final String condition;
  final String? brand;
  final String? video;
  final int? stock;
  final String? description;
  final CategoryRef? category;
  final CategoryRef? subcategory;
  final ProductSeller? seller;
  final List<String> deliveryOptions;
  final bool featured;
  final String status;
  final List<ProductSpec> specs;
  final List<String> sizeOptions;
  final List<String> colorOptions;
  final String? sellerLocationLabel;

  bool get isNew => condition.toLowerCase() == 'new';
  bool get isUsed => condition.toLowerCase() == 'used';
  bool get isRefurbished => condition.toLowerCase() == 'refurbished';
  bool get isOnSale => originalPrice != null && originalPrice! > price;
  bool get isAvailable => status != 'rejected' && status != 'draft';
  int get discount => discountPercent ??
      (isOnSale && originalPrice! > 0
          ? (((originalPrice! - price) / originalPrice!) * 100).round()
          : 0);

  double? get rating {
    if (ratingAvg != null && ratingAvg! > 0) return ratingAvg;
    return null;
  }

  factory Product.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid product payload');
    }

    List<String> imgList = const [];
    final rawImages = json['images'];
    if (rawImages is List) {
      imgList = rawImages
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      imgList = [rawImages];
    }

    final num basePrice = (json['price'] as num?)?.toDouble() ?? 0;
    final num? apiDiscount = _numOrNull(json['discountPrice']);
    final num? apiOriginal = _numOrNull(json['originalPrice']);
    final bool onSale = apiDiscount != null && apiDiscount > 0 && apiDiscount < basePrice;

    return Product(
      id: json['id'].toString(),
      name: resolveString(json['name'], fallback: 'Product'),
      slug: json['slug']?.toString() ?? '',
      images: imgList,
      price: onSale ? apiDiscount.toDouble() : basePrice.toDouble(),
      originalPrice: onSale ? (apiOriginal ?? basePrice) : apiOriginal,
      discountPercent: (json['discountPercent'] as num?)?.toInt(),
      discountEndsAt: tryParseDate(json['discountEndsAt']),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      salesCount: (json['salesCount'] as num?)?.toInt(),
      viewsCount: (json['viewsCount'] as num?)?.toInt(),
      condition: json['condition']?.toString().toLowerCase() ?? 'new',
      brand: json['brand']?.toString(),
      video: json['video']?.toString(),
      stock: (json['stock'] as num?)?.toInt(),
      description: resolveString(json['description']),
      category: CategoryRef.fromApi(json['category'] ?? json['categoryId']),
      subcategory: CategoryRef.fromApi(json['subcategory'] ?? json['subcategoryId']),
      seller: ProductSeller.fromPopulated(
        store: _mapOrNull(json['storeId']),
        user: _mapOrNull(json['sellerId']),
        legacy: json['seller'] ?? json['store'],
      ),
      deliveryOptions: _stringList(json['deliveryOptions']),
      featured: json['featured'] == true,
      status: json['status']?.toString() ?? 'active',
      specs: ProductSpec.fromApi(json['specifications'] ?? json['specs']),
      sizeOptions: _stringList(json['sizeOptions']),
      colorOptions: _stringList(json['colorOptions']),
      sellerLocationLabel: json['sellerLocation']?.toString(),
    );
  }

  static Map<String, dynamic>? _mapOrNull(Object? v) =>
      v is Map<String, dynamic> ? v : null;

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  static num? _numOrNull(dynamic v) {
    if (v is num) return v;
    return null;
  }
}