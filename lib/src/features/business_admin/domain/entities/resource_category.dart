import 'package:equatable/equatable.dart';

class ResourceCategory extends Equatable {
  const ResourceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.businessId,
  });

  final String id;
  final String name;
  final String description;
  final String businessId;

  @override
  List<Object?> get props => [id, name, description, businessId];
}
