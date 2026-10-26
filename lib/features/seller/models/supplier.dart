import 'package:intl/intl.dart';

import '../../../core/currency/currencies.dart';

/// One entry in the admin-managed dropship supplier directory.
///
/// Mirrors the seller-facing `GET /supplier/suppliers` payload: payout details
/// are never included, only the public storefront-style contact fields.
class SupplierSummary {
  const SupplierSummary({
    required this.id,
    required this.name,
    this.company,
    this.logo,
    this.email,
    this.phone,
    this.currency = 'USD',
  });

  final String id;
  final String name;
  final String? company;
  final String? logo;
  final String? email;
  final String? phone;
  final String currency;

  factory SupplierSummary.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const SupplierSummary(id: '', name: '');
    return SupplierSummary(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      company: _nonEmpty(json['company']),
      logo: _nonEmpty(json['logo']),
      email: _nonEmpty(json['email']),
      phone: _nonEmpty(json['phone']),
      currency: (json['currency']?.toString() ?? 'USD').toUpperCase(),
    );
  }
}

/// A product in one supplier's catalog (`GET /supplier/suppliers/:id/products`).
class SupplierItem {
  const SupplierItem({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    this.image,
    this.images = const [],
    this.cost = 0,
    this.currency = 'USD',
    this.stock,
  });

  final String id;
  final String name;
  final String? sku;
  final String? description;
  final String? image;
  final List<String> images;
  final num cost;
  final String currency;
  final int? stock;

  /// Supplier gallery, falling back to the single legacy `image` cover.
  List<String> get gallery {
    if (images.isNotEmpty) return images;
    final cover = image;
    return cover == null || cover.isEmpty ? const [] : [cover];
  }

  bool get inStock => stock == null || stock! > 0;

  factory SupplierItem.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const SupplierItem(id: '', name: '');
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return SupplierItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: _nonEmpty(json['sku']),
      description: _nonEmpty(json['description']),
      image: _nonEmpty(json['image']),
      images: images,
      cost: (json['cost'] as num?) ?? 0,
      currency: (json['currency']?.toString() ?? 'USD').toUpperCase(),
      stock: (json['stock'] as num?)?.toInt(),
    );
  }
}

/// The supplier + product chosen in the dropship picker and handed to the
/// normal product form as its prefill.
class DropshipSelection {
  const DropshipSelection({
    required this.supplierId,
    required this.supplierName,
    required this.item,
  });

  final String supplierId;
  final String supplierName;
  final SupplierItem item;
}

/// Supplier costs are quoted in the supplier's own currency (usually USD), not
/// the app's RWF base unit, so they must be formatted directly.
String formatSupplierCost(num amount, String currency) {
  final code = currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase();
  final def = isSupportedCurrency(code) ? currencyDef(code) : null;
  return NumberFormat.simpleCurrency(
    locale: 'en_US',
    name: code,
    decimalDigits: def?.decimals ?? 2,
  ).format(amount);
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
