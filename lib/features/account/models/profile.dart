import '../../../core/utils/formatters.dart';

class Address {
  const Address({
    required this.id,
    this.label,
    this.fullName,
    this.phone,
    this.country,
    this.city,
    this.district,
    this.street,
    this.notes,
    this.isDefault = false,
  });

  final String id;
  final String? label;
  final String? fullName;
  final String? phone;
  final String? country;
  final String? city;
  final String? district;
  final String? street;
  final String? notes;
  final bool isDefault;

  String get display {
    final parts = [label, fullName, [street, district, city].where((e) => e != null && e.isNotEmpty).join(', ')]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .toList();
    return parts.join(' • ');
  }

  factory Address.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid address');
    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString(),
      fullName: (json['fullName'] ?? json['name'])?.toString(),
      phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
      country: json['country']?.toString(),
      city: resolveString(json['city']),
      district: json['district']?.toString(),
      street: json['streetAddress']?.toString() ?? json['street']?.toString(),
      notes: json['notes']?.toString(),
      isDefault: json['isDefault'] == true || json['default'] == true,
    );
  }
}

class AddressBook {
  const AddressBook({this.addresses = const []});

  final List<Address> addresses;

  factory AddressBook.parse(dynamic data) {
    if (data is List) {
      return AddressBook(addresses: data.map(Address.fromApi).toList());
    }
    return const AddressBook();
  }
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    this.logo,
    this.description,
    this.mobileMoney = false,
  });

  final String id;
  final String name;
  final String? logo;
  final String? description;
  final bool mobileMoney;

  static const defaults = [
    PaymentMethod(id: 'mpesa', name: 'M-Pesa', mobileMoney: true, description: 'Vodafone / Safaricom mobile money'),
    PaymentMethod(id: 'airtel_money', name: 'Airtel Money', mobileMoney: true, description: 'Airtel mobile money'),
    PaymentMethod(id: 't_kash', name: 'T-Kash', mobileMoney: true, description: 'Tigo mobile money'),
    PaymentMethod(id: 'pesalink', name: 'PesaLink', mobileMoney: false, description: 'Bank to bank instant transfer'),
    PaymentMethod(id: 'bank_transfer', name: 'Bank Transfer', mobileMoney: false, description: 'Direct bank transfer'),
    PaymentMethod(id: 'card', name: 'Card', mobileMoney: false, description: 'Debit / credit card'),
  ];

  factory PaymentMethod.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid payment method');
    final name = (json['name'] ?? json['label'])?.toString() ?? '';
    return PaymentMethod(
      id: json['id']?.toString() ?? name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      mobileMoney: json['mobileMoney'] == true || json['type'] == 'momo',
    );
  }
}

class Wallet {
  const Wallet({this.balance = 0, this.points = 0, this.membership});

  final num balance;
  final int points;
  final String? membership;

  factory Wallet.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) return const Wallet();
    return Wallet(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      membership: json['membershipBundle']?.toString() ?? json['membership']?.toString(),
    );
  }
}

class Review {
  const Review({
    required this.id,
    this.rating,
    this.comment,
    this.createdAt,
    this.authorName,
    this.productName,
    this.sellerName,
  });

  final String id;
  final num? rating;
  final String? comment;
  final DateTime? createdAt;
  final String? authorName;
  final String? productName;
  final String? sellerName;

  factory Review.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid review');
    final author = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : json['authorId'] is Map<String, dynamic>
            ? json['authorId'] as Map<String, dynamic>
            : const <String, dynamic>{};
    // On /reviews/my the server populates `targetId` with the reviewed item:
    //   product → { name, slug, images }, seller → { storeName, storeSlug, logoUrl }.
    final target = json['targetId'] is Map<String, dynamic>
        ? json['targetId'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return Review(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment']?.toString(),
      createdAt: tryParseDate(json['createdAt']),
      authorName: (author['fullName'] ?? author['name'])?.toString(),
      productName: json['productName']?.toString() ?? target['name']?.toString(),
      sellerName: json['sellerName']?.toString() ?? target['storeName']?.toString(),
    );
  }
}