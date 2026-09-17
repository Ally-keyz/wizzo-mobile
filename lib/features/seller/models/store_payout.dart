import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// How the platform pays the seller's sales earnings out: MoMo payouts are
/// pushed automatically via PawaPay, card payouts are settled manually.
enum SellerPayoutMethod {
  mobileMoney,
  card;

  static SellerPayoutMethod fromApi(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'momo':
        return SellerPayoutMethod.mobileMoney;
      case 'card':
        return SellerPayoutMethod.card;
      default:
        return SellerPayoutMethod.mobileMoney;
    }
  }

  String get apiValue => switch (this) {
    SellerPayoutMethod.mobileMoney => 'momo',
    SellerPayoutMethod.card => 'card',
  };

  String label(BuildContext context) => switch (this) {
    SellerPayoutMethod.mobileMoney => context.tr('seller.payout.mobileMoney'),
    SellerPayoutMethod.card => context.tr('seller.payout.cardBank'),
  };
}

/// The seller's payout destination (where Wizzo sends their earnings).
class StorePayout {
  const StorePayout({
    required this.method,
    this.provider,
    this.accountName,
    this.accountNumber,
  });

  final SellerPayoutMethod method;
  final String? provider;
  final String? accountName;
  final String? accountNumber;

  bool get hasDetails =>
      (accountName?.trim().isNotEmpty ?? false) &&
      (accountNumber?.trim().isNotEmpty ?? false);

  factory StorePayout.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const StorePayout(
        method: SellerPayoutMethod.mobileMoney,
      );
    }
    return StorePayout(
      method: SellerPayoutMethod.fromApi(json['method']),
      provider: json['provider']?.toString(),
      accountName: json['accountName']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'method': method.apiValue,
    if (provider != null && provider!.trim().isNotEmpty)
      'provider': provider!.trim(),
    if (accountName != null && accountName!.trim().isNotEmpty)
      'accountName': accountName!.trim(),
    if (accountNumber != null && accountNumber!.trim().isNotEmpty)
      'accountNumber': accountNumber!.trim(),
  };

  StorePayout copyWith({
    SellerPayoutMethod? method,
    String? provider,
    String? accountName,
    String? accountNumber,
  }) {
    return StorePayout(
      method: method ?? this.method,
      provider: provider ?? this.provider,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }
}