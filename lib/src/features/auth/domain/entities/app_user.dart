import 'package:equatable/equatable.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../booking/domain/entities/business.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    required this.ownedBusinesses,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final Role role;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Business> ownedBusinesses;

  String get fullName => '$firstName $lastName'.trim();

  AppUser copyWith({List<Business>? ownedBusinesses}) {
    return AppUser(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: role,
      isActive: isActive,
      isVerified: isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
      ownedBusinesses: ownedBusinesses ?? this.ownedBusinesses,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        phone,
        role,
        isActive,
        isVerified,
        createdAt,
        updatedAt,
        ownedBusinesses,
      ];
}
