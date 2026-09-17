import '../../../../core/enums/app_enums.dart';
import '../models/app_user_model.dart';
import '../models/auth_session_model.dart';
import '../models/otp_verification_result_model.dart';
import '../models/password_reset_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AppUserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  });

  Future<OtpVerificationResultModel> verifyOtp({
    required String email,
    required String otp,
  });

  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<PasswordResetRequestModel> requestPasswordReset({
    required String emailOrUsername,
  });

  Future<PasswordResetConfirmationModel> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  });
}
