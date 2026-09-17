import 'package:bookat/src/features/auth/data/models/otp_verification_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `POST /auth/verify-otp` confirms success with a message, a token pair and
/// the verified user — it never sends a `success` flag. The model used to read
/// one anyway, so it parsed as `false` and the repository turned a successful
/// verification into "The verification code is not valid."
void main() {
  test('the real success response parses as success', () {
    // Captured from the live API on 2026-09-11.
    final result = OtpVerificationResultModel.fromJson({
      'message': 'Email verified successfully',
      'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.access',
      'refresh_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh',
      'user': {
        'id': '8d8ecf78-b5ce-47ee-999a-58deffb60667',
        'email': 'mr.masoodshahkk@gmail.com',
        'firstName': 'masood',
        'lastName': 'shah',
        'phone': '03135589192',
        'role': 'CUSTOMER',
        'isActive': true,
        'isVerified': true,
      },
    });

    expect(result.success, isTrue);
    expect(result.message, 'Email verified successfully');
  });

  test('a bare 2xx with only a message still counts as success', () {
    // A rejected code never reaches the model — it arrives as a non-2xx and is
    // raised by the network layer first.
    final result = OtpVerificationResultModel.fromJson({
      'message': 'Email verified successfully',
    });

    expect(result.success, isTrue);
  });

  test('an explicit success flag is still honoured', () {
    expect(
      OtpVerificationResultModel.fromJson({
        'success': true,
        'message': 'ok',
      }).success,
      isTrue,
    );

    // If the API ever starts reporting failure in a 200 body, respect it.
    expect(
      OtpVerificationResultModel.fromJson({
        'success': false,
        'message': 'Invalid code',
      }).success,
      isFalse,
    );
  });

  test('a string flag from a loosely typed backend is read correctly', () {
    expect(
      OtpVerificationResultModel.fromJson({'success': 'true'}).success,
      isTrue,
    );
    expect(
      OtpVerificationResultModel.fromJson({'verified': 'false'}).success,
      isFalse,
    );
  });

  test('a missing message degrades to empty rather than throwing', () {
    final result = OtpVerificationResultModel.fromJson({
      'access_token': 'token',
    });

    expect(result.success, isTrue);
    expect(result.message, isEmpty);
  });
}
