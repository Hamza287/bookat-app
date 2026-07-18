class Business {
  const Business({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.logoUrl,
    required this.coverUrl,
    required this.type,
    required this.businessModel,
    required this.city,
    required this.address,
    required this.settings,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.resources,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String type;
  final String businessModel;
  final String city;
  final String address;
  final BusinessSettings settings;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BusinessResource> resources;
}

class BusinessSettings {
  const BusinessSettings({required this.category, required this.currency});

  final String category;
  final String currency;
}

class BusinessResource {
  const BusinessResource({required this.data});

  final Map<String, dynamic> data;
}
