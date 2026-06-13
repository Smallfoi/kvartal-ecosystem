enum LoginProvider { email, phone, google, apple }

class SavedAddress {
  final String label;
  final String city;
  final String street;
  final String house;
  final String? apartment;
  final String? postalCode;

  const SavedAddress({
    this.label = '',
    required this.city,
    required this.street,
    required this.house,
    this.apartment,
    this.postalCode,
  });

  String get displayLine {
    final parts = [city, street, house].where((s) => s.isNotEmpty).join(', ');
    final apt = apartment != null ? ', кв. $apartment' : '';
    return '$parts$apt';
  }

  String get displayTitle => label.isNotEmpty ? label : displayLine;

  Map<String, dynamic> toJson() => {
        'label': label,
        'city': city,
        'street': street,
        'house': house,
        'apartment': apartment,
        'postalCode': postalCode,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        label: j['label'] as String? ?? '',
        city: j['city'] as String? ?? '',
        street: j['street'] as String? ?? '',
        house: j['house'] as String? ?? '',
        apartment: j['apartment'] as String?,
        postalCode: j['postalCode'] as String?,
      );
}

class AuthUser {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final LoginProvider provider;
  final List<SavedAddress> addresses;
  final String? avatarPath;

  const AuthUser({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.provider = LoginProvider.email,
    this.addresses = const [],
    this.avatarPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'provider': provider.name,
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'avatarPath': avatarPath,
      };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String?,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        provider: LoginProvider.values.firstWhere(
          (e) => e.name == j['provider'],
          orElse: () => LoginProvider.email,
        ),
        addresses: (j['addresses'] as List? ?? [])
            .map((a) => SavedAddress.fromJson(a as Map<String, dynamic>))
            .toList(),
        avatarPath: j['avatarPath'] as String?,
      );
}

class OAuthPendingData {
  final String name;
  final String email;
  final LoginProvider provider;

  const OAuthPendingData({
    required this.name,
    required this.email,
    required this.provider,
  });
}
