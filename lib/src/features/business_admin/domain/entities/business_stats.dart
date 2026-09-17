import 'package:equatable/equatable.dart';

class BusinessStats extends Equatable {
  const BusinessStats({
    required this.todayRevenue,
    required this.appointmentsToday,
    required this.activeResources,
    required this.occupancyRate,
    required this.chartData,
  });

  final num todayRevenue;
  final int appointmentsToday;
  final int activeResources;
  final String occupancyRate;
  final List<BusinessChartPoint> chartData;

  @override
  List<Object?> get props => [
        todayRevenue,
        appointmentsToday,
        activeResources,
        occupancyRate,
        chartData,
      ];
}

class BusinessChartPoint extends Equatable {
  const BusinessChartPoint({
    required this.name,
    required this.revenue,
  });

  final String name;
  final num revenue;

  @override
  List<Object?> get props => [name, revenue];
}
