import '../../../../core/enums/app_enums.dart';
import '../../../booking/data/models/business_model.dart';
import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.phone,
    required super.role,
    required super.isActive,
    required super.isVerified,
    required super.createdAt,
    required super.updatedAt,
    required super.ownedBusinesses,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: _string(json['id']),
      email: _string(json['email']),
      firstName: _string(json['firstName']),
      lastName: _string(json['lastName']),
      phone: _string(json['phone']),
      role: Role.fromValue(_string(json['role'], fallback: Role.customer.value)),
      isActive: _bool(json['isActive']),
      isVerified: _bool(json['isVerified']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      ownedBusinesses: _list(json['ownedBusinesses'])
          .whereType<Map<String, dynamic>>()
          .map(BusinessModel.fromJson)
          .toList(growable: false),
    );
  }

  factory AppUserModel.fromEntity(AppUser user) {
    return AppUserModel(
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      role: user.role,
      isActive: user.isActive,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      ownedBusinesses: user.ownedBusinesses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'role': role.value,
      'isActive': isActive,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ownedBusinesses': ownedBusinesses
          .map((business) => BusinessModel.fromEntity(business).toJson())
          .toList(growable: false),
    };
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<dynamic> _list(Object? value) {
  return value is List ? value : const [];
}
