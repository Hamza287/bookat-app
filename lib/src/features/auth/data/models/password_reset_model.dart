import '../../domain/entities/password_reset.dart';

/// Parses `POST /auth/forgot-password`, which answers `201` with:
///
/// ```json
/// {"message": "Password reset OTP has been sent to your email address (a@b.com).",
///  "email": "a@b.com"}
/// ```
class PasswordResetRequestModel extends PasswordResetRequest {
  const PasswordResetRequestModel({
    required super.email,
    required super.message,
  });

  factory PasswordResetRequestModel.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequestModel(
      email: json['email']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

/// Parses `POST /auth/reset-password`, which answers `201` with a message and
/// nothing else:
///
/// ```json
/// {"message": "Password reset successful. You can now log in with your new password."}
/// ```
class PasswordResetConfirmationModel extends PasswordResetConfirmation {
  const PasswordResetConfirmationModel({required super.message});

  factory PasswordResetConfirmationModel.fromJson(Map<String, dynamic> json) {
    return PasswordResetConfirmationModel(
      message: json['message']?.toString() ?? '',
    );
  }
}
