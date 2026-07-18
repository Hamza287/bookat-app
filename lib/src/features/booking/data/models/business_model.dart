import '../../domain/entities/business.dart';

class BusinessModel extends Business {
  const BusinessModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.description,
    required super.logoUrl,
    required super.coverUrl,
    required super.type,
    required super.businessModel,
    required super.city,
    required super.address,
    required super.settings,
    required super.ownerId,
    required super.createdAt,
    required super.updatedAt,
    required super.resources,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      logoUrl: json['logoUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      type: json['type'] as String? ?? '',
      businessModel: json['businessModel'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      settings: BusinessSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>? ?? const {},
      ),
      ownerId: json['ownerId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      resources: (json['resources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BusinessResourceModel.fromJson)
          .toList(growable: false),
    );
  }
}

class BusinessSettingsModel extends BusinessSettings {
  const BusinessSettingsModel({required super.category, required super.currency});

  factory BusinessSettingsModel.fromJson(Map<String, dynamic> json) {
    return BusinessSettingsModel(
      category: json['category'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
    );
  }
}

class BusinessResourceModel extends BusinessResource {
  const BusinessResourceModel({required super.data});

  factory BusinessResourceModel.fromJson(Map<String, dynamic> json) {
    return BusinessResourceModel(data: json);
  }
}
