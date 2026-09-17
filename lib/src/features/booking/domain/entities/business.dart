import 'package:equatable/equatable.dart';

class Business extends Equatable {
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
    required this.averageRating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.services,
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
  final double averageRating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BusinessService> services;
  final List<BusinessResource> resources;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        logoUrl,
        coverUrl,
        type,
        businessModel,
        city,
        address,
        settings,
        ownerId,
        averageRating,
        reviewCount,
        createdAt,
        updatedAt,
        services,
        resources,
      ];
}

class BusinessSettings extends Equatable {
  const BusinessSettings({
    required this.category,
    required this.currency,
    required this.operatingHours,
    required this.cancellationPolicy,
    required this.theme,
  });

  final String category;
  final String currency;
  final List<BusinessOperatingHour> operatingHours;
  final BusinessCancellationPolicy cancellationPolicy;
  final BusinessTheme theme;

  BusinessSettings copyWith({
    String? category,
    String? currency,
    List<BusinessOperatingHour>? operatingHours,
    BusinessCancellationPolicy? cancellationPolicy,
    BusinessTheme? theme,
  }) {
    return BusinessSettings(
      category: category ?? this.category,
      currency: currency ?? this.currency,
      operatingHours: operatingHours ?? this.operatingHours,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      theme: theme ?? this.theme,
    );
  }

  @override
  List<Object?> get props => [
        category,
        currency,
        operatingHours,
        cancellationPolicy,
        theme,
      ];
}

class BusinessOperatingHour extends Equatable {
  const BusinessOperatingHour({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isOffDay,
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isOffDay;

  BusinessOperatingHour copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isOffDay,
  }) {
    return BusinessOperatingHour(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isOffDay: isOffDay ?? this.isOffDay,
    );
  }

  @override
  List<Object?> get props => [dayOfWeek, startTime, endTime, isOffDay];
}

class BusinessCancellationPolicy extends Equatable {
  const BusinessCancellationPolicy({
    required this.isAllowed,
    required this.windowUnit,
    required this.windowValue,
  });

  final bool isAllowed;
  final String windowUnit;
  final int windowValue;

  BusinessCancellationPolicy copyWith({
    bool? isAllowed,
    String? windowUnit,
    int? windowValue,
  }) {
    return BusinessCancellationPolicy(
      isAllowed: isAllowed ?? this.isAllowed,
      windowUnit: windowUnit ?? this.windowUnit,
      windowValue: windowValue ?? this.windowValue,
    );
  }

  @override
  List<Object?> get props => [isAllowed, windowUnit, windowValue];
}

/// Colours for the customer-facing booking page. Persisted as flat
/// `theme*` keys inside the business `settings` object.
class BusinessTheme extends Equatable {
  const BusinessTheme({
    required this.primaryColor,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightText,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkText,
  });

  static const defaults = BusinessTheme(
    primaryColor: '#2563eb',
    lightBackground: '#f8fafc',
    lightSurface: '#ffffff',
    lightText: '#0f172a',
    darkBackground: '#0f172a',
    darkSurface: '#1e293b',
    darkText: '#f8fafc',
  );

  final String primaryColor;
  final String lightBackground;
  final String lightSurface;
  final String lightText;
  final String darkBackground;
  final String darkSurface;
  final String darkText;

  BusinessTheme copyWith({
    String? primaryColor,
    String? lightBackground,
    String? lightSurface,
    String? lightText,
    String? darkBackground,
    String? darkSurface,
    String? darkText,
  }) {
    return BusinessTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      lightBackground: lightBackground ?? this.lightBackground,
      lightSurface: lightSurface ?? this.lightSurface,
      lightText: lightText ?? this.lightText,
      darkBackground: darkBackground ?? this.darkBackground,
      darkSurface: darkSurface ?? this.darkSurface,
      darkText: darkText ?? this.darkText,
    );
  }

  @override
  List<Object?> get props => [
        primaryColor,
        lightBackground,
        lightSurface,
        lightText,
        darkBackground,
        darkSurface,
        darkText,
      ];
}

class BusinessService extends Equatable {
  const BusinessService({required this.data});

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class BusinessResource extends Equatable {
  const BusinessResource({required this.data});

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}
