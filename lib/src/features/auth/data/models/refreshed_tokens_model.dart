/// Token pair returned by `POST /auth/refresh`.
///
/// The endpoint answers with tokens only — no user profile — so a refreshed
/// session reuses the stored user. Both snake_case and camelCase spellings are
/// accepted because the login and verify-otp responses use `access_token`
/// while some deployments return `accessToken`.
class RefreshedTokensModel {
  const RefreshedTokensModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshedTokensModel.fromJson(Map<String, dynamic> json) {
    final accessToken = _string(json, ['access_token', 'accessToken']);
    if (accessToken.isEmpty) {
      throw const FormatException('Invalid refresh response.');
    }

    return RefreshedTokensModel(
      accessToken: accessToken,
      refreshToken: _string(json, ['refresh_token', 'refreshToken']),
    );
  }

  final String accessToken;

  /// Empty when the server reissues only the access token; callers keep the
  /// refresh token they already hold in that case.
  final String refreshToken;
}

String _string(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}
