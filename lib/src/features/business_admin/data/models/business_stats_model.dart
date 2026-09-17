import '../../domain/entities/business_stats.dart';

class BusinessStatsModel extends BusinessStats {
  const BusinessStatsModel({
    required super.todayRevenue,
    required super.appointmentsToday,
    required super.activeResources,
    required super.occupancyRate,
    required super.chartData,
  });

  factory BusinessStatsModel.fromJson(Map<String, dynamic> json) {
    return BusinessStatsModel(
      todayRevenue: _num(json['todayRevenue']),
      appointmentsToday: _int(json['appointmentsToday']),
      activeResources: _int(json['activeResources']),
      occupancyRate: _string(json['occupancyRate']),
      chartData: _list(json['chartData'])
          .whereType<Map<String, dynamic>>()
          .map(BusinessChartPointModel.fromJson)
          .toList(growable: false),
    );
  }
}

class BusinessChartPointModel extends BusinessChartPoint {
  const BusinessChartPointModel({
    required super.name,
    required super.revenue,
  });

  factory BusinessChartPointModel.fromJson(Map<String, dynamic> json) {
    return BusinessChartPointModel(
      name: _string(json['name']),
      revenue: _num(json['revenue']),
    );
  }
}

String _string(Object? value) {
  return value?.toString() ?? '';
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

num _num(Object? value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

List<dynamic> _list(Object? value) {
  return value is List ? value : const [];
}
