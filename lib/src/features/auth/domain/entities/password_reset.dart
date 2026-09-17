import 'package:equatable/equatable.dart';

/// Outcome of `POST /auth/forgot-password`.
///
/// The request is made with an email *or* a username, and the server answers
/// with the address it actually sent the code to — so the next screen can tell
/// the user which inbox to check even when they typed a username.
class PasswordResetRequest extends Equatable {
  const PasswordResetRequest({required this.email, required this.message});

  final String email;
  final String message;

  @override
  List<Object?> get props => [email, message];
}

/// Outcome of `POST /auth/reset-password`.
///
/// Carries only the server's confirmation message: this endpoint does not
/// return a session, so the user signs in again with their new password.
class PasswordResetConfirmation extends Equatable {
  const PasswordResetConfirmation({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
