import '../../domain/entities/otp_verification_result.dart';

/// Parses `POST /auth/verify-otp`, which answers a successful verification with
/// the message, a token pair and the verified user — and **no `success` flag**:
///
/// ```json
/// {"message": "Email verified successfully",
///  "access_token": "...", "refresh_token": "...",
///  "user": {"id": "...", "isVerified": true, ...}}
/// ```
///
/// Reading a `success` key that is never sent made every verification parse as
/// a failure, so the app reported "The verification code is not valid" for
/// codes the server had just accepted.
class OtpVerificationResultModel extends OtpVerificationResult {
  const OtpVerificationResultModel({
    required super.success,
    required super.message,
  });

  factory OtpVerificationResultModel.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResultModel(
      success: _success(json),
      message: json['message']?.toString() ?? '',
    );
  }
}

/// A rejected code comes back as a non-2xx status, which the network layer
/// raises before this is ever reached — so arriving here already means the
/// server accepted it.
///
/// An explicit flag is still honoured in case the API grows one, and the token
/// and user fields are treated as positive confirmation.
bool _success(Map<String, dynamic> json) {
  final flag = json['success'] ?? json['verified'] ?? json['isVerified'];
  if (flag != null) {
    return _bool(flag);
  }

  if (json['access_token'] != null ||
      json['accessToken'] != null ||
      json['user'] != null) {
    return true;
  }

  // No flag and no payload to check: the 2xx is the only signal there is, and
  // it means the code was valid.
  return true;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}
