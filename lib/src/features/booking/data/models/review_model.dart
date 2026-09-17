import '../../domain/entities/review.dart';

/// A single entry of `GET /reviews/business/{businessId}`. Confirmed against the
/// live API, which returns:
///
/// ```json
/// {"id": "...", "rating": 4, "comment": "nice", "userId": "...",
///  "businessId": "...", "bookingId": "...", "createdAt": "2026-07-30T11:49:48.357Z",
///  "user": {"firstName": "John", "lastName": "Doe", "id": "..."}}
/// ```
///
/// The alternative key spellings below are kept as a cheap safety net for
/// other deployments; `rating`, `comment`, `createdAt` and the nested `user`
/// are the ones this API actually sends.
class ReviewModel extends Review {
  const ReviewModel({
    required super.id,
    required super.rating,
    required super.comment,
    required super.customerName,
    required super.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: _string(json, ['id', 'reviewId']),
      rating: _rating(json),
      comment: _string(json, ['comment', 'review', 'text', 'message']),
      customerName: _customerName(json),
      createdAt: _date(json, ['createdAt', 'created_at']),
    );
  }
}

String _string(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}

int _rating(Map<String, dynamic> json) {
  for (final key in ['rating', 'stars', 'score']) {
    final value = json[key];
    if (value is num) {
      return value.round().clamp(0, 5);
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed.clamp(0, 5);
    }
  }
  return 0;
}

String _customerName(Map<String, dynamic> json) {
  final direct = _string(json, ['customerName', 'authorName', 'name']);
  if (direct.isNotEmpty) {
    return direct;
  }

  for (final key in ['customer', 'user', 'author']) {
    final nested = json[key];
    if (nested is Map<String, dynamic>) {
      final first = _string(nested, ['firstName']);
      final last = _string(nested, ['lastName']);
      final full = '$first $last'.trim();
      if (full.isNotEmpty) {
        return full;
      }
      final name = _string(nested, ['name']);
      if (name.isNotEmpty) {
        return name;
      }
    }
  }

  return 'Bookat customer';
}

DateTime? _date(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
