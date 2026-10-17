/// Modelo del perfil de usuario en Quincena.
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.currency = 'GTQ',
    this.defaultIncome = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String currency;
  final double defaultIncome;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@').first;
    }
    return 'Usuario Quincena';
  }

  String get initials {
    final name = displayName;
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'Q';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? userEmail}) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: userEmail ?? json['email'] as String?,
      fullName: json['full_name'] as String? ?? json['fullName'] as String?,
      currency: json['currency'] as String? ?? json['default_currency'] as String? ?? 'GTQ',
      defaultIncome: (json['default_income'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'currency': currency,
        'default_income': defaultIncome,
      };

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? currency,
    double? defaultIncome,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      currency: currency ?? this.currency,
      defaultIncome: defaultIncome ?? this.defaultIncome,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
