import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../core/config/app_config.dart';
import '../core/network/network.dart';
import '../features/booking/data/datasources/booking_remote_data_source.dart';
import '../features/booking/data/datasources/dio_booking_remote_data_source.dart';
import '../features/booking/data/datasources/mock_booking_remote_data_source.dart';
import '../features/booking/data/repositories/booking_repository_impl.dart';
import '../features/booking/domain/repositories/booking_repository.dart';
import '../features/booking/domain/usecases/search_businesses.dart';

final serviceLocator = GetIt.instance;

Future<void> configureDependencies({bool? useMockData}) async {
  if (serviceLocator.isRegistered<Dio>()) {
    return;
  }

  final shouldUseMockData = useMockData ?? AppConfig.useMockData;

  serviceLocator
    ..registerLazySingleton<Dio>(DioFactory.create)
    ..registerLazySingleton<ApiClient>(() => ApiClient(serviceLocator<Dio>()))
    ..registerLazySingleton<BookingRemoteDataSource>(
      () => shouldUseMockData
          ? const MockBookingRemoteDataSource()
          : DioBookingRemoteDataSource(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<BookingRepository>(
      () => BookingRepositoryImpl(serviceLocator<BookingRemoteDataSource>()),
    )
    ..registerFactory(
      () => SearchBusinesses(serviceLocator<BookingRepository>()),
    );
}
