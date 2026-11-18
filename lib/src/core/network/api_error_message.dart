import 'package:dio/dio.dart';

/// The server's own explanation for a failed request, or null when it gave none.
///
/// Every non-2xx response from this API carries a `message`, and it is shown to
/// the user as-is — "Cancellation not allowed within 1 hours of the booking
/// time" tells them what to do, where a generic "this booking can no longer be
/// cancelled" does not. Whatever the API says wins; the app's own wording is
/// only a fallback for when no message comes back at all.
///
/// Returns null for transport failures (timeout, no connection), which have no
/// response body and where a server message would be invented.
String? apiErrorMessage(Object error) {
  if (error is! DioException) {
    return null;
  }

  final data = error.response?.data;
  if (data is! Map) {
    return null;
  }

  final message = data['message'];

  if (message is String) {
    final trimmed = message.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // Validation failures arrive as a list of field errors; showing them on
  // separate lines keeps each one readable.
  if (message is List) {
    final lines = message
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    return lines.isEmpty ? null : lines.join('\n');
  }

  return null;
}
