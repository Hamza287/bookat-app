import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:flutter_test/flutter_test.dart';

/// The API replaces the stored `settings` object wholesale on every PATCH, so
/// a dropped key here silently deletes live business configuration.
void main() {
  const settingsJson = <String, dynamic>{
    'currency': 'PKR',
    'operatingHours': [
      {
        'endTime': '00:00',
        'isOffDay': false,
        'dayOfWeek': 1,
        'startTime': '09:00',
      },
      {
        'endTime': '00:00',
        'isOffDay': true,
        'dayOfWeek': 0,
        'startTime': '09:00',
      },
    ],
    'cancellationPolicy': {
      'isAllowed': false,
      'windowValue': 24,
      'windowUnit': 'HOURS',
    },
    'themePrimaryColor': '#2563eb',
    'themeLightBgColor': '#f8fafc',
    'themeLightSurfaceColor': '#ffffff',
    'themeLightTextColor': '#0f172a',
    'themeDarkBgColor': '#0f172a',
    'themeDarkSurfaceColor': '#1e293b',
    'themeDarkTextColor': '#f8fafc',
  };

  group('BusinessSettingsModel', () {
    test('round-trips every field the dashboard sends', () {
      final settings = BusinessSettingsModel.fromJson(settingsJson);
      final encoded = BusinessSettingsModel.fromEntity(settings).toJson();

      expect(encoded['currency'], 'PKR');
      expect(encoded['operatingHours'], settingsJson['operatingHours']);
      expect(encoded['cancellationPolicy'], settingsJson['cancellationPolicy']);
      for (final key in settingsJson.keys.where((k) => k.startsWith('theme'))) {
        expect(encoded[key], settingsJson[key], reason: '$key was dropped');
      }
    });

    test('changing currency preserves hours, policy and theme', () {
      final original = BusinessSettingsModel.fromJson(settingsJson);
      final merged = original.copyWith(currency: 'USD');
      final encoded = BusinessSettingsModel.fromEntity(merged).toJson();

      expect(encoded['currency'], 'USD');
      expect(encoded['operatingHours'], settingsJson['operatingHours']);
      expect(encoded['cancellationPolicy'], settingsJson['cancellationPolicy']);
      expect(encoded['themePrimaryColor'], '#2563eb');
      expect(encoded['themeDarkSurfaceColor'], '#1e293b');
    });

    test('changing theme preserves hours and cancellation policy', () {
      final original = BusinessSettingsModel.fromJson(settingsJson);
      final merged = original.copyWith(
        theme: original.theme.copyWith(primaryColor: '#ef4444'),
      );
      final encoded = BusinessSettingsModel.fromEntity(merged).toJson();

      expect(encoded['themePrimaryColor'], '#ef4444');
      expect(encoded['themeLightBgColor'], '#f8fafc');
      expect(encoded['operatingHours'], settingsJson['operatingHours']);
      expect(encoded['cancellationPolicy'], settingsJson['cancellationPolicy']);
    });

    test('falls back to default theme colours when the API omits them', () {
      final settings = BusinessSettingsModel.fromJson({
        'currency': 'PKR',
        'themePrimaryColor': '',
      });

      // Compared by props: models extend entities, and Equatable also compares
      // runtimeType, so BusinessThemeModel is never == BusinessTheme.
      expect(settings.theme.props, BusinessTheme.defaults.props);
    });
  });
}
