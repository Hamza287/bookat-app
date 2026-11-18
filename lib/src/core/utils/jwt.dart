import 'dart:convert';

/// Reads the expiry out of a JWT without verifying it.
///
/// Verification is the server's job — the client only needs to know whether a
/// token is already spent, so it can refresh before making a call rather than
/// letting the call fail and refreshing afterwards.
///
/// Returns null for anything that is not a readable JWT with an `exp` claim.
/// Callers treat null as "cannot tell", never as "expired": signing a user out
/// because a token could not be parsed would be worse than letting the request
/// try and fail.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }

  try {
    // JWTs use base64url without padding; normalize() restores it.
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final exp = decoded['exp'];
    if (exp is! num) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
  } catch (_) {
    return null;
  }
}

/// Whether [token] is expired, or close enough that it would likely expire
/// mid-flight.
///
/// [leeway] covers clock skew between device and server plus the round trip; a
/// token with thirty seconds left is treated as spent so the user does not hit
/// a 401 halfway through an operation.
bool isJwtExpired(
  String token, {
  Duration leeway = const Duration(minutes: 1),
  DateTime? now,
}) {
  final expiry = jwtExpiry(token);
  if (expiry == null) {
    return false;
  }

  final reference = (now ?? DateTime.now()).toUtc();
  return !expiry.isAfter(reference.add(leeway));
}
