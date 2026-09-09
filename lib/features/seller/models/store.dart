import '../../../core/utils/formatters.dart';
import 'payment_account.dart';

/// The signed-in user's own store (GET /sellers/me and /sellers/register).
class MyStore {
  const MyStore({
    required this.id,
    required this.storeName,
    required this.storeSlug,
    this.userId,
    this.logoUrl,
    this.coverUrl,
    this.aboutStore,
    this.country,
    this.district,
    this.city,
    this.verified = false,
    this.verificationStatus = 'pending',
    this.status = 'active',
    this.ratingAvg,
    this.ratingCount,
    this.productsCount,
    this.followersCount,
    this.deliveryOptions = const [],
    this.paymentMethodsAccepted = const [],
    this.paymentAccounts = const [],
  });

  final String id;
  final String storeName;
  final String storeSlug;
  final String? userId;
  final String? logoUrl;
  final String? coverUrl;
  final String? aboutStore;
  final String? country;
  final String? district;
  final String? city;
  final bool verified;
  final String verificationStatus;
  final String status;
  final double? ratingAvg;
  final int? ratingCount;
  final int? productsCount;
  final int? followersCount;
  final List<String> deliveryOptions;
  final List<String> paymentMethodsAccepted;
  final List<PaymentAccount> paymentAccounts;

  bool get isSuspended => status == 'suspended';
  bool get isVerified => verified || verificationStatus == 'verified';

  String get locationLabel {
    final parts = [city, district, country]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString())
        .toList();
    return parts.join(', ');
  }

  factory MyStore.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid store payload');
    }
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final rawAcc = json['paymentAccounts'];
    return MyStore(
      id: id,
      storeName: resolveString(json['storeName'], fallback: 'Your store'),
      storeSlug: json['storeSlug']?.toString() ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['id'] ?? json['userId']['_id'] ?? '').toString()
          : json['userId']?.toString(),
      logoUrl: _stripOrNull(json['logoUrl']),
      coverUrl: _stripOrNull(json['coverUrl']),
      aboutStore: resolveString(json['aboutStore']),
      country: resolveString(json['country']),
      district: resolveString(json['district']),
      city: resolveString(json['city']),
      verified: json['verifiedBadge'] == true || json['verified'] == true,
      verificationStatus: json['verificationStatus']?.toString() ?? 'pending',
      status: json['status']?.toString() ?? 'active',
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      productsCount: (json['productsCount'] as num?)?.toInt(),
      followersCount: (json['followersCount'] as num?)?.toInt(),
      deliveryOptions: _stringList(json['deliveryOptions']),
      paymentMethodsAccepted: _stringList(json['paymentMethodsAccepted']),
      paymentAccounts: rawAcc is List
          ? rawAcc.map(PaymentAccount.fromApi).toList()
          : const [],
    );
  }

  static String? _stripOrNull(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  MyStore copyWith({
    String? storeName,
    String? storeSlug,
    String? logoUrl,
    String? coverUrl,
    String? aboutStore,
    String? country,
    String? district,
    String? city,
    List<String>? deliveryOptions,
    List<String>? paymentMethodsAccepted,
    List<PaymentAccount>? paymentAccounts,
  }) {
    return MyStore(
      id: id,
      storeName: storeName ?? this.storeName,
      storeSlug: storeSlug ?? this.storeSlug,
      userId: userId,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      aboutStore: aboutStore ?? this.aboutStore,
      country: country ?? this.country,
      district: district ?? this.district,
      city: city ?? this.city,
      verified: verified,
      verificationStatus: verificationStatus,
      status: status,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      productsCount: productsCount,
      followersCount: followersCount,
      deliveryOptions: deliveryOptions ?? this.deliveryOptions,
      paymentMethodsAccepted:
          paymentMethodsAccepted ?? this.paymentMethodsAccepted,
      paymentAccounts: paymentAccounts ?? this.paymentAccounts,
    );
  }
}