import '../../domain/entities/business_category.dart';

class BusinessCategoryModel extends BusinessCategory {
  const BusinessCategoryModel({required super.value, required super.label});

  /// `/config/categories` may return either a bare list of strings
  /// (`["SPORTS_GROUND", "SALON"]`) or a list of `{value, label}` objects.
  /// Both are accepted since the exact shape is not documented.
  factory BusinessCategoryModel.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      final value = (json['value'] ?? json['id'] ?? json['key'] ?? '').toString();
      final label = (json['label'] ?? json['name'] ?? value).toString();
      return BusinessCategoryModel(value: value, label: label);
    }

    final value = json?.toString() ?? '';
    return BusinessCategoryModel(value: value, label: _titleCase(value));
  }
}

String _titleCase(String value) {
  final words = value.toLowerCase().split(RegExp(r'[_\s]+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
