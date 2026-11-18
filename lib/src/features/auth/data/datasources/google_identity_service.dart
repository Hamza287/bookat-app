import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Raised when the Google or Firebase side of the flow fails in a way worth
/// telling the user about. A dismissed account picker is not one of these.
class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.message);

  final String message;

  @override
  String toString() => 'GoogleIdentityException: $message';
}

/// Produces the Firebase ID token that `POST /auth/google` verifies.
///
/// Kept behind an interface so the repository can be exercised without the
/// platform SDKs, which need a real device to run.
abstract interface class GoogleIdentityService {
  /// Shows the Google account picker and exchanges the chosen account for a
  /// Firebase ID token.
  ///
  /// Returns null when the user dismisses the picker — a decision, not a
  /// failure, so it must not surface as an error.
  Future<String?> obtainIdToken();

  /// Forgets the signed-in Google account so the next attempt shows the picker
  /// rather than silently reusing the last one.
  Future<void> signOut();
}

class FirebaseGoogleIdentityService implements GoogleIdentityService {
  FirebaseGoogleIdentityService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? serverClientId,
  })  : _injectedFirebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _serverClientId =
            (serverClientId == null || serverClientId.isEmpty) ? null : serverClientId;

  final FirebaseAuth? _injectedFirebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// Resolved on first use, not at construction: `FirebaseAuth.instance`
  /// throws until `Firebase.initializeApp` has run, and this service is built
  /// alongside the auth repository — long before anyone taps Google.
  FirebaseAuth get _firebaseAuth =>
      _injectedFirebaseAuth ?? FirebaseAuth.instance;

  /// The OAuth web client id. Left null, the Android plugin falls back to the
  /// `default_web_client_id` resource that google-services.json generates.
  final String? _serverClientId;

  /// `initialize` may be called exactly once per instance, so the future is
  /// cached rather than the call repeated per sign-in attempt.
  Future<void>? _initialization;

  @override
  Future<String?> obtainIdToken() async {
    await _initialize();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw GoogleIdentityException(_describe(error));
    }

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw const GoogleIdentityException(
        'Google did not return a sign-in token. Please try again.',
      );
    }

    // The backend verifies a *Firebase* ID token, so the Google token is
    // traded for a Firebase session first.
    try {
      final credential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleIdToken),
      );

      final firebaseIdToken = await credential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const GoogleIdentityException(
          'We could not confirm your Google account. Please try again.',
        );
      }

      return firebaseIdToken;
    } on FirebaseAuthException catch (error) {
      throw GoogleIdentityException(
        error.message ?? 'We could not confirm your Google account.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    // Best effort on both halves: being unable to clear the Google account
    // must not keep the user signed in to the app.
    try {
      await _initialize();
      await _googleSignIn.signOut();
    } catch (_) {
      // Nothing to recover — the local session is cleared either way.
    }

    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // As above.
    }
  }

  Future<void> _initialize() {
    return _initialization ??= _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );
  }

  /// Turns a plugin failure into something a user can act on. The misconfigured
  /// cases are by far the most common during setup, and "something went wrong"
  /// hides them.
  String _describe(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is not configured for this app yet.',
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in was interrupted. Please try again.',
      _ => error.description ?? 'We could not sign you in with Google.',
    };
  }
}
