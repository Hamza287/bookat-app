import 'package:equatable/equatable.dart';

/// A business category as returned by `/config/categories`, e.g. the value
/// `SPORTS_GROUND` sent back to the search endpoint's `type` query parameter,
/// paired with a display label.
class BusinessCategory extends Equatable {
  const BusinessCategory({required this.value, required this.label});

  final String value;
  final String label;

  @override
  List<Object?> get props => [value, label];
}
