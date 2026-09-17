import '../../domain/entities/resource_category.dart';

class ResourceCategoryModel extends ResourceCategory {
  const ResourceCategoryModel({
    required super.id,
    required super.name,
    required super.description,
    required super.businessId,
  });

  factory ResourceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ResourceCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      businessId: json['businessId']?.toString() ?? '',
    );
  }
}
