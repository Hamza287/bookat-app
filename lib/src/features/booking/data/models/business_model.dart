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
    required super.averageRating,
    required super.reviewCount,
    required super.createdAt,
    required super.updatedAt,
    required super.services,
    required super.resources,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: _string(json['id']),
      name: _string(json['name']),
      slug: _string(json['slug']),
      description: _nullableString(json['description']),
      logoUrl: _nullableString(json['logoUrl']),
      coverUrl: _nullableString(json['coverUrl']),
      type: _string(json['type']),
      businessModel: _string(json['businessModel']),
      city: _string(json['city']),
      address: _string(json['address']),
      settings: BusinessSettingsModel.fromJson(
        _map(json['settings']),
        fallbackCategory: _string(json['type']),
      ),
      ownerId: _string(json['ownerId']),
      averageRating: _double(json['averageRating']),
      reviewCount: _int(json['reviewCount']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      services: _list(json['services'])
          .whereType<Map<String, dynamic>>()
          .map(BusinessServiceModel.fromJson)
          .toList(growable: false),
      resources: _list(json['resources'])
          .whereType<Map<String, dynamic>>()
          .map(BusinessResourceModel.fromJson)
          .toList(growable: false),
    );
  }

  factory BusinessModel.fromEntity(Business business) {
    return BusinessModel(
      id: business.id,
      name: business.name,
      slug: business.slug,
      description: business.description,
      logoUrl: business.logoUrl,
      coverUrl: business.coverUrl,
      type: business.type,
      businessModel: business.businessModel,
      city: business.city,
      address: business.address,
      settings: business.settings,
      ownerId: business.ownerId,
      averageRating: business.averageRating,
      reviewCount: business.reviewCount,
      createdAt: business.createdAt,
      updatedAt: business.updatedAt,
      services: business.services,
      resources: business.resources,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'type': type,
      'businessModel': businessModel,
      'city': city,
      'address': address,
      'settings': BusinessSettingsModel.fromEntity(settings).toJson(),
      'ownerId': ownerId,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'services': services.map((service) => service.data).toList(growable: false),
      'resources': resources.map((resource) => resource.data).toList(growable: false),
    };
  }
}

class BusinessSettingsModel extends BusinessSettings {
  const BusinessSettingsModel({
    required super.category,
    required super.currency,
    required super.operatingHours,
    required super.cancellationPolicy,
    required super.theme,
  });

  factory BusinessSettingsModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackCategory = '',
  }) {
    return BusinessSettingsModel(
      category: _string(json['category'], fallback: fallbackCategory),
      currency: _string(json['currency']),
      operatingHours: _list(json['operatingHours'])
          .whereType<Map<String, dynamic>>()
          .map(BusinessOperatingHourModel.fromJson)
          .toList(growable: false),
      cancellationPolicy: BusinessCancellationPolicyModel.fromJson(
        _map(json['cancellationPolicy']),
      ),
      theme: BusinessThemeModel.fromJson(json),
    );
  }

  factory BusinessSettingsModel.fromEntity(BusinessSettings settings) {
    return BusinessSettingsModel(
      category: settings.category,
      currency: settings.currency,
      operatingHours: settings.operatingHours,
      cancellationPolicy: settings.cancellationPolicy,
      theme: settings.theme,
    );
  }

  /// The API replaces `settings` wholesale on every update, so this must always
  /// emit the complete object — omitting a key deletes it server-side.
  Map<String, dynamic> toJson() {
    return {
      if (category.isNotEmpty) 'category': category,
      'currency': currency,
      'operatingHours': operatingHours
          .map((hour) => {
                'dayOfWeek': hour.dayOfWeek,
                'startTime': hour.startTime,
                'endTime': hour.endTime,
                'isOffDay': hour.isOffDay,
              })
          .toList(growable: false),
      'cancellationPolicy': {
        'isAllowed': cancellationPolicy.isAllowed,
        'windowUnit': cancellationPolicy.windowUnit,
        'windowValue': cancellationPolicy.windowValue,
      },
      ...BusinessThemeModel.fromEntity(theme).toJson(),
    };
  }
}

class BusinessThemeModel extends BusinessTheme {
  const BusinessThemeModel({
    required super.primaryColor,
    required super.lightBackground,
    required super.lightSurface,
    required super.lightText,
    required super.darkBackground,
    required super.darkSurface,
    required super.darkText,
  });

  /// Reads the flat `theme*` keys off the settings object itself.
  factory BusinessThemeModel.fromJson(Map<String, dynamic> settings) {
    const fallback = BusinessTheme.defaults;

    return BusinessThemeModel(
      primaryColor: _color(settings['themePrimaryColor'], fallback.primaryColor),
      lightBackground: _color(
        settings['themeLightBgColor'],
        fallback.lightBackground,
      ),
      lightSurface: _color(
        settings['themeLightSurfaceColor'],
        fallback.lightSurface,
      ),
      lightText: _color(settings['themeLightTextColor'], fallback.lightText),
      darkBackground: _color(
        settings['themeDarkBgColor'],
        fallback.darkBackground,
      ),
      darkSurface: _color(
        settings['themeDarkSurfaceColor'],
        fallback.darkSurface,
      ),
      darkText: _color(settings['themeDarkTextColor'], fallback.darkText),
    );
  }

  factory BusinessThemeModel.fromEntity(BusinessTheme theme) {
    return BusinessThemeModel(
      primaryColor: theme.primaryColor,
      lightBackground: theme.lightBackground,
      lightSurface: theme.lightSurface,
      lightText: theme.lightText,
      darkBackground: theme.darkBackground,
      darkSurface: theme.darkSurface,
      darkText: theme.darkText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themePrimaryColor': primaryColor,
      'themeLightBgColor': lightBackground,
      'themeLightSurfaceColor': lightSurface,
      'themeLightTextColor': lightText,
      'themeDarkBgColor': darkBackground,
      'themeDarkSurfaceColor': darkSurface,
      'themeDarkTextColor': darkText,
    };
  }
}

class BusinessOperatingHourModel extends BusinessOperatingHour {
  const BusinessOperatingHourModel({
    required super.dayOfWeek,
    required super.startTime,
    required super.endTime,
    required super.isOffDay,
  });

  factory BusinessOperatingHourModel.fromJson(Map<String, dynamic> json) {
    return BusinessOperatingHourModel(
      dayOfWeek: _int(json['dayOfWeek']),
      startTime: _string(json['startTime']),
      endTime: _string(json['endTime']),
      isOffDay: _bool(json['isOffDay']),
    );
  }
}

class BusinessCancellationPolicyModel extends BusinessCancellationPolicy {
  const BusinessCancellationPolicyModel({
    required super.isAllowed,
    required super.windowUnit,
    required super.windowValue,
  });

  factory BusinessCancellationPolicyModel.fromJson(Map<String, dynamic> json) {
    return BusinessCancellationPolicyModel(
      isAllowed: _bool(json['isAllowed']),
      windowUnit: _string(json['windowUnit']),
      windowValue: _int(json['windowValue']),
    );
  }
}

class BusinessServiceModel extends BusinessService {
  const BusinessServiceModel({required super.data});

  factory BusinessServiceModel.fromJson(Map<String, dynamic> json) {
    return BusinessServiceModel(data: _safeMap(json));
  }
}

class BusinessResourceModel extends BusinessResource {
  const BusinessResourceModel({required super.data});

  factory BusinessResourceModel.fromJson(Map<String, dynamic> json) {
    return BusinessResourceModel(data: _safeMap(json));
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

/// Theme colours fall back to the platform defaults when the API omits them or
/// returns a blank string.
String _color(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<dynamic> _list(Object? value) {
  return value is List ? value : const [];
}

Map<String, dynamic> _map(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

Map<String, dynamic> _safeMap(Map<String, dynamic> json) {
  return json.map((key, value) {
    if (value is Map<String, dynamic>) {
      return MapEntry(key, _safeMap(value));
    }
    if (value is List) {
      return MapEntry(key, value.where((item) => item != null).toList());
    }
    return MapEntry(key, value ?? '');
  });
}
