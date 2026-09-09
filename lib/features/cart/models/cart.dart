import '../../catalog/models/product.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.variantSize,
    this.variantColor,
    this.sellerId,
    this.sellerName,
    this.sellerLogo,
    this.sellerVerified = false,
  });

  final String id;
  final Product product;
  final int quantity;
  final String? variantSize;
  final String? variantColor;

  /// Seller user id (the `sellerId` field on the cart item). This is what the
  /// server uses to group cart items and match `sellerPaymentSelection`.
  final String? sellerId;
  final String? sellerName;
  final String? sellerLogo;
  final bool sellerVerified;

  num get lineTotal => product.price * quantity;

  factory CartItem.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid cart item');
    final id =
        json['_id']?.toString() ?? json['id']?.toString() ?? json['productId']?.toString() ?? '';
    final rawProduct = json['product'] ?? json['productId'];
    final Product product;
    if (rawProduct is Map<String, dynamic>) {
      product = Product.fromApi(rawProduct);
    } else {
      // Mutating cart endpoints may return unpopulated items (productId is a
      // raw id string). Keep the row usable until the next populated fetch.
      product = Product(
        id: rawProduct?.toString() ?? id,
        name: json['name']?.toString() ?? 'Product',
        slug: '',
        images: const [],
        price: (json['priceSnapshot'] as num?)?.toDouble() ?? 0,
      );
    }

    // The /cart payload carries the seller as a populated user doc (or a plain
    // id string) on the ITEM, not on the product. Product.fromApi only reads
    // `seller`/`store`, which are absent here, so thread the seller through.
    final rawSeller = json['sellerId'] ?? json['seller'];
    String? sellerId;
    String? sellerName;
    String? sellerFullName;
    String? sellerLogo;
    String? sellerAvatar;
    var sellerVerified = false;
    if (rawSeller is Map<String, dynamic>) {
      sellerId = (rawSeller['id'] ?? rawSeller['_id'] ?? '').toString();
      sellerName = rawSeller['storeName']?.toString();
      sellerFullName = rawSeller['fullName']?.toString();
      sellerLogo = rawSeller['logoUrl']?.toString();
      sellerAvatar = rawSeller['avatarUrl']?.toString();
      sellerVerified = rawSeller['verifiedBadge'] == true;
    } else {
      final idStr = rawSeller?.toString() ?? '';
      sellerId = idStr.isEmpty ? null : idStr;
    }
    if (rawProduct is Map<String, dynamic>) {
      final storeRaw = rawProduct['storeId'] ?? rawProduct['store'];
      if (storeRaw is Map<String, dynamic>) {
        sellerName ??= storeRaw['storeName']?.toString();
        sellerLogo ??= storeRaw['logoUrl']?.toString();
        sellerVerified = sellerVerified || storeRaw['verifiedBadge'] == true;
      }
    }
    // Prefer the store name/logo for display, falling back to the seller's
    // fullName/avatar from the user payload.
    sellerName ??= sellerFullName;
    sellerLogo ??= sellerAvatar;

    return CartItem(
      id: id,
      product: product,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      variantSize: json['selectedSize']?.toString() ??
          json['size']?.toString() ??
          json['variantSize']?.toString(),
      variantColor: json['selectedColor']?.toString() ??
          json['color']?.toString() ??
          json['variantColor']?.toString(),
      sellerId: sellerId,
      sellerName: sellerName,
      sellerLogo: sellerLogo,
      sellerVerified: sellerVerified,
    );
  }
}

class CartSellerGroup {
  const CartSellerGroup({
    required this.sellerId,
    this.sellerName,
    this.sellerSlug,
    this.sellerLogo,
    this.verified = false,
    this.items = const [],
  });

  final String sellerId;
  final String? sellerName;
  final String? sellerSlug;
  final String? sellerLogo;
  final bool verified;
  final List<CartItem> items;

  num get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  CartSellerGroup copyWith({List<CartItem>? items}) =>
      CartSellerGroup(
        sellerId: sellerId,
        sellerName: sellerName,
        sellerSlug: sellerSlug,
        sellerLogo: sellerLogo,
        verified: verified,
        items: items ?? this.items,
      );
}

class CartData {
  const CartData({
    this.groups = const [],
    this.itemCount = 0,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.total = 0,
  });

  final List<CartSellerGroup> groups;
  final int itemCount;
  final num subtotal;
  final num deliveryFee;
  final num total;

  static const empty = CartData();

  factory CartData.fromApi(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return CartData.fromItems(const []);
    }
    final raw = data['items'] ?? data['cartItems'] ?? data['groups'];

    if (data['groups'] is List) {
      final groups = (data['groups'] as List).map((g) {
        final m = g as Map<String, dynamic>;
        return CartSellerGroup(
          sellerId: (m['sellerId'] ?? m['seller']?['id'])?.toString() ?? '',
          sellerName: m['seller']?['storeName']?.toString() ?? m['sellerName']?.toString(),
          sellerSlug: m['seller']?['storeSlug']?.toString(),
          sellerLogo: m['seller']?['logoUrl']?.toString(),
          verified: m['seller']?['verifiedBadge'] == true,
          items: _itemList(m['items'] ?? m['products']),
        );
      }).toList();
      return CartData(
        groups: groups,
        itemCount: (data['totalQuantity'] as num?)?.toInt() ??
            groups.fold(0, (s, g) => s + g.items.fold(0, (a, i) => a + i.quantity)),
        subtotal: (data['subtotal'] as num?)?.toDouble() ??
            groups.fold(0, (s, g) => s + g.subtotal),
        deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
        total: (data['total'] as num?)?.toDouble() ?? 0,
      );
    }

    return CartData.fromItems(raw is List ? raw : const []);
  }

  static List<CartItem> _itemList(dynamic items) {
    if (items is! List) return const [];
    return items.map((e) => CartItem.fromApi(e)).toList();
  }

  static CartData fromItems(List<dynamic> items) {
    final parsed = items.map(CartItem.fromApi).toList();
    final bySeller = <String, List<CartItem>>{};
    for (final item in parsed) {
      final key = (item.sellerId?.isNotEmpty == true)
          ? item.sellerId!
          : (item.product.seller?.id?.isNotEmpty == true
              ? item.product.seller!.id!
              : 'other');
      bySeller.putIfAbsent(key, () => []).add(item);
    }
    final groups = bySeller.entries.map((e) {
      final first = e.value.first;
      final seller = first.product.seller;
      return CartSellerGroup(
        sellerId: e.key,
        sellerName: first.sellerName ?? seller?.storeName,
        sellerSlug: seller?.storeSlug,
        sellerLogo: first.sellerLogo ?? seller?.logoUrl,
        verified: first.sellerVerified || (seller?.verified ?? false),
        items: e.value,
      );
    }).toList();
    return CartData(
      groups: groups,
      itemCount: parsed.fold(0, (s, i) => s + i.quantity),
      subtotal: parsed.fold(0, (s, i) => s + i.lineTotal),
    );
  }
}