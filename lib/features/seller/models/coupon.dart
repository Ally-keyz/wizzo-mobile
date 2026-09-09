import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../core/utils/formatters.dart';

enum DiscountType {
  percent,
  fixed;

  static DiscountType fromApi(dynamic v) =>
      v?.toString().toLowerCase() == 'fixed'
      ? DiscountType.fixed
      : DiscountType.percent;

  String get apiValue => this == DiscountType.fixed ? 'fixed' : 'percent';

  String label(BuildContext context) => this == DiscountType.fixed
      ? context.tr('seller.discount.fixedAmount')
      : context.tr('seller.discount.percentage');
}

/// A seller coupon bound to one of the seller's products.
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.productId,
    this.productName,
    this.productImage,
    this.maxUses,
    this.timesUsed = 0,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.description,
  });

  final String id;
  final String code;
  final DiscountType discountType;
  final int discountValue;
  final String? productId;
  final String? productName;
  final String? productImage;
  final int? maxUses;
  final int timesUsed;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? description;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get notStarted => startsAt != null && startsAt!.isAfter(DateTime.now());
  bool get usedUp => maxUses != null && timesUsed >= maxUses!;

  String valueLabel(BuildContext context) {
    if (discountType == DiscountType.percent) {
      return context.tr(
        'seller.couponValuePercent',
        namedArgs: {'value': '$discountValue'},
      );
    }
    return context.tr(
      'seller.couponValueFixed',
      namedArgs: {'value': '$discountValue'},
    );
  }

  factory Coupon.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>)
      throw const FormatException('Invalid coupon payload');
    final product = json['productId'];
    final productMap = product is Map<String, dynamic> ? product : null;
    return Coupon(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      discountType: DiscountType.fromApi(json['discountType']),
      discountValue: (json['discountValue'] as num?)?.toInt() ?? 0,
      productId:
          productMap?['id']?.toString() ??
          productMap?['_id']?.toString() ??
          product?.toString(),
      productName: productMap?['name']?.toString(),
      productImage: productMap?['images'] is List
          ? (productMap?['images'] as List).firstOrNull?.toString()
          : null,
      maxUses: (json['maxUses'] as num?)?.toInt(),
      timesUsed: (json['timesUsed'] as num?)?.toInt() ?? 0,
      startsAt: tryParseDate(json['startsAt']),
      expiresAt: tryParseDate(json['expiresAt']),
      isActive: json['isActive'] != false,
      description: json['description']?.toString(),
    );
  }
}

/// Payload used when creating/updating a coupon.
class CouponInput {
  const CouponInput({
    required this.productId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxUses,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.description,
  });

  final String productId;
  final String code;
  final DiscountType discountType;
  final int discountValue;
  final int? maxUses;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? description;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'code': code.trim().toUpperCase(),
    'discountType': discountType.apiValue,
    'discountValue': discountValue,
    if (maxUses != null) 'maxUses': maxUses,
    if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (!isActive) 'isActive': false,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
  };
}
