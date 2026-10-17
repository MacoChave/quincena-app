/// Modelo de usuario autenticado en Quincena.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.defaultCurrency = 'GTQ',
  });

  final String id;
  final String email;
  final String? fullName;
  final String defaultCurrency;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['fullName'] as String?,
      defaultCurrency: json['default_currency'] as String? ??
          json['defaultCurrency'] as String? ??
          'GTQ',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'default_currency': defaultCurrency,
      };

  AuthUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? defaultCurrency,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    );
  }
}
