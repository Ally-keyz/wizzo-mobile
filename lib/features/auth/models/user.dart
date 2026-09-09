/// Authenticated user snapshot kept in Riverpod state.
class User {
  const User({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.provider = 'email',
    this.role = 'buyer',
    this.membershipBundle,
    this.emailVerified = false,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String provider;
  final String role;
  final String? membershipBundle;
  final bool emailVerified;

  bool get isSeller => role == 'seller' || role == 'vendor';
  String get shortName {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) {
      final at = email?.indexOf('@');
      if (at != null && at > 0) return email!.substring(0, at);
      return 'User';
    }
    final parts = name.split(' ');
    final initials = parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
    return initials.isEmpty ? name.toUpperCase() : initials;
  }

  factory User.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const User(id: '');
    }
    final role = (json['role'] ?? json['roleId'])?.toString() ?? 'buyer';
    final rawId = (json['id'] ?? json['_id'])?.toString();
    if (rawId == null || rawId.isEmpty) {
      return const User(id: '');
    }
    return User(
      id: rawId,
      fullName: (json['fullName'] ?? json['name'])?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'])?.toString(),
      provider: json['provider']?.toString() ?? 'email',
      role: role,
      membershipBundle: json['membershipBundle']?.toString(),
      emailVerified:
          json['isEmailVerified'] == true || json['emailVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'avatar': avatarUrl,
    'provider': provider,
    'role': role,
    'membershipBundle': membershipBundle,
    'emailVerified': emailVerified,
  };

  factory User.fromJson(Map<String, dynamic> json) => User.fromApi(json);

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? provider,
    String? role,
    String? membershipBundle,
    bool? emailVerified,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      provider: provider ?? this.provider,
      role: role ?? this.role,
      membershipBundle: membershipBundle ?? this.membershipBundle,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
