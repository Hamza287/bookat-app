import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/domain/entities/otp_verification_result.dart';
import 'package:bookat/src/features/auth/domain/entities/password_reset.dart';
import 'package:bookat/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `ownedBusinesses` is cached in the stored session at login. A settings save
/// that only updates memory looks fine until the next app start, then silently
/// reverts to the login snapshot.
void main() {
  Business business({required String name}) {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': name,
      'slug': 'bats-and-balls',
      'city': 'Islamabad',
      'address': 'Sohni Road',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
    });
  }

  AuthSession sessionWith(Business value) {
    return AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AppUser(
        id: 'owner-1',
        email: 'owner@example.com',
        firstName: 'Hamza',
        lastName: 'Ibrahim',
        phone: '03001234567',
        role: Role.businessAdmin,
        isActive: true,
        isVerified: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        ownedBusinesses: [value],
      ),
    );
  }

  test('saving a business rewrites the persisted session', () async {
    final repository = _FakeAuthRepository(sessionWith(business(name: 'Old')));
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    expect(container.read(activeBusinessProvider)?.name, 'Old');

    await container
        .read(authControllerProvider.notifier)
        .updateOwnedBusiness(business(name: 'New'));

    // In memory...
    expect(container.read(activeBusinessProvider)?.name, 'New');
    // ...and on disk, which is what survives a restart.
    expect(repository.saved?.user.ownedBusinesses.single.name, 'New');
  });

  test('adds the business when the session has none yet', () async {
    final empty = AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: sessionWith(business(name: 'Old')).user.copyWith(
            ownedBusinesses: const [],
          ),
    );
    final repository = _FakeAuthRepository(empty);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    expect(container.read(activeBusinessProvider), isNull);

    await container
        .read(authControllerProvider.notifier)
        .updateOwnedBusiness(business(name: 'First'));

    expect(container.read(activeBusinessProvider)?.name, 'First');
    expect(repository.saved?.user.ownedBusinesses.single.name, 'First');
  });

  test('does nothing when signed out', () async {
    final repository = _FakeAuthRepository(null);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .updateOwnedBusiness(business(name: 'Ignored'));

    expect(repository.saved, isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._stored);

  AuthSession? _stored;
  AuthSession? saved;

  @override
  Future<AuthSession?> readSession() async => _stored;

  @override
  Future<void> saveSession(AuthSession session) async {
    saved = session;
    _stored = session;
  }

  @override
  Future<void> clearSession() async {
    _stored = null;
  }

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<AuthSession?>> signInWithGoogle({
    Role role = Role.customer,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOutOfGoogle() async {}

  @override
  Future<Result<AuthSession>> refreshSession({
    required String refreshToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout({
    required String accessToken,
    required String fcmToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<PasswordResetRequest>> requestPasswordReset({
    required String emailOrUsername,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<PasswordResetConfirmation>> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<AppUser>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<OtpVerificationResult>> verifyOtp({
    required String email,
    required String otp,
  }) =>
      throw UnimplementedError();
}
