import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Where a store receives money for out-of-band manual payments.
enum PaymentMethodKind {
  mobileMoney,
  bank,
  cashOnDelivery;

  static PaymentMethodKind fromApi(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'momo':
        return PaymentMethodKind.mobileMoney;
      case 'bank':
        return PaymentMethodKind.bank;
      case 'cash_on_delivery':
        return PaymentMethodKind.cashOnDelivery;
      default:
        return PaymentMethodKind.mobileMoney;
    }
  }

  String get apiValue => switch (this) {
    PaymentMethodKind.mobileMoney => 'momo',
    PaymentMethodKind.bank => 'bank',
    PaymentMethodKind.cashOnDelivery => 'cash_on_delivery',
  };

  String label(BuildContext context) => switch (this) {
    PaymentMethodKind.mobileMoney => context.tr('seller.payment.mobileMoney'),
    PaymentMethodKind.bank => context.tr('seller.payment.bankAccount'),
    PaymentMethodKind.cashOnDelivery => context.tr('orders.cashOnDelivery'),
  };
}

/// One payout / pay-to account a store advertises to buyers.
class PaymentAccount {
  const PaymentAccount({
    required this.method,
    this.provider,
    required this.accountName,
    required this.accountNumber,
    this.instructions,
  });

  final PaymentMethodKind method;
  final String? provider;
  final String accountName;
  final String accountNumber;
  final String? instructions;

  factory PaymentAccount.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const PaymentAccount(
        method: PaymentMethodKind.mobileMoney,
        accountName: '',
        accountNumber: '',
      );
    }
    return PaymentAccount(
      method: PaymentMethodKind.fromApi(json['method']),
      provider: json['provider']?.toString(),
      accountName: json['accountName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'method': method.apiValue,
    if (provider != null && provider!.trim().isNotEmpty)
      'provider': provider!.trim(),
    'accountName': accountName.trim(),
    'accountNumber': accountNumber.trim(),
    if (instructions != null && instructions!.trim().isNotEmpty)
      'instructions': instructions!.trim(),
  };

  PaymentAccount copyWith({
    PaymentMethodKind? method,
    String? provider,
    String? accountName,
    String? accountNumber,
    String? instructions,
  }) {
    return PaymentAccount(
      method: method ?? this.method,
      provider: provider ?? this.provider,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      instructions: instructions ?? this.instructions,
    );
  }
}
