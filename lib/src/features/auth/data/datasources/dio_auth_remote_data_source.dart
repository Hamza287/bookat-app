import '../../../../core/enums/app_enums.dart';
import '../../../../core/network/network.dart';
import '../models/app_user_model.dart';
import '../models/auth_session_model.dart';
import '../models/otp_verification_result_model.dart';
import '../models/password_reset_model.dart';
import 'auth_remote_data_source.dart';

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AppUserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authRegister,
      data: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'role': role.value,
      },
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration response.');
    }

    return AppUserModel.fromJson(payload);
  }

  @override
  Future<OtpVerificationResultModel> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authVerifyOtp,
      data: {
        'email': email,
        'otp': otp,
      },
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid verification response.');
    }

    return OtpVerificationResultModel.fromJson(payload);
  }

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authLogin,
      data: {
        'email': email,
        'password': password,
      },
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response.');
    }

    return AuthSessionModel.fromJson(payload);
  }

  @override
  Future<PasswordResetRequestModel> requestPasswordReset({
    required String emailOrUsername,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authForgotPassword,
      data: {'emailOrUsername': emailOrUsername},
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid password reset response.');
    }

    return PasswordResetRequestModel.fromJson(payload);
  }

  @override
  Future<PasswordResetConfirmationModel> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authResetPassword,
      data: {
        'emailOrUsername': emailOrUsername,
        'otp': otp,
        'newPassword': newPassword,
      },
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid password reset response.');
    }

    return PasswordResetConfirmationModel.fromJson(payload);
  }
}
