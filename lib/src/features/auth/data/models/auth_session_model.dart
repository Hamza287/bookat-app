import '../../domain/entities/auth_session.dart';
import 'app_user_model.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.accessToken,
    required super.refreshToken,
    required super.user,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      return AuthSessionModel(
        accessToken: json['access_token']?.toString() ?? '',
        refreshToken: json['refresh_token']?.toString() ?? '',
        user: AppUserModel.fromJson(const {}),
      );
    }

    return AuthSessionModel(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      user: AppUserModel.fromJson(userJson),
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession session) {
    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: AppUserModel.fromEntity(session.user),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': AppUserModel.fromEntity(user).toJson(),
    };
  }
}
