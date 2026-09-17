import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import '../../../booking/data/models/business_model.dart';
import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../../../booking/domain/entities/my_booking.dart';
import '../../domain/entities/business_payment.dart';
import '../../domain/entities/business_stats.dart';
import '../../domain/entities/holiday_booking_check.dart';
import '../../domain/entities/resource_category.dart';
import '../../domain/repositories/business_admin_repository.dart';
import '../datasources/business_admin_remote_data_source.dart';

import '../../domain/entities/schedule_exception.dart';

class BusinessAdminRepositoryImpl implements BusinessAdminRepository {
  const BusinessAdminRepositoryImpl(this._remoteDataSource);

  final BusinessAdminRemoteDataSource _remoteDataSource;

  @override
  Future<Result<Business>> updateBusiness({
    required String businessId,
    required String accessToken,
    required String name,
    required String slug,
    required String city,
    required String address,
    required BusinessSettings settings,
    String? logoPath,
    String? coverPath,
  }) async {
    try {
      final business = await _remoteDataSource.updateBusiness(
        businessId: businessId,
        accessToken: accessToken,
        fields: {
          'name': name,
          'slug': slug,
          'city': city,
          'address': address,
          'settings': jsonEncode(
            BusinessSettingsModel.fromEntity(settings).toJson(),
          ),
        },
        logoPath: logoPath,
        coverPath: coverPath,
      );
      return Success(business);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _settingsMessage(e.response?.statusCode)),
      );
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not save your business details.'),
      );
    }
  }

  @override
  Future<Result<Business>> updateOperatingHours({
    required String businessId,
    required String accessToken,
    required List<BusinessOperatingHour> operatingHours,
  }) async {
    try {
      final business = await _remoteDataSource.updateOperatingHours(
        businessId: businessId,
        accessToken: accessToken,
        operatingHours: operatingHours
            .map((hour) => {
                  'dayOfWeek': hour.dayOfWeek,
                  'startTime': hour.startTime,
                  'endTime': hour.endTime,
                  'isOffDay': hour.isOffDay,
                })
            .toList(growable: false),
      );
      return Success(business);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _settingsMessage(e.response?.statusCode)),
      );
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not save your operating hours.'),
      );
    }
  }

  @override
  Future<Result<HolidayBookingCheck>> checkHolidayBookings({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
  }) async {
    try {
      final check = await _remoteDataSource.checkHolidayBookings(
        businessId: businessId,
        accessToken: accessToken,
        date: _isoDate(date),
        endDate: _isoDate(endDate),
      );
      return Success(check);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _settingsMessage(e.response?.statusCode)),
      );
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not check this date range.'),
      );
    }
  }

  @override
  Future<Result<void>> createHoliday({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    try {
      await _remoteDataSource.createHoliday(
        businessId: businessId,
        accessToken: accessToken,
        date: _isoDate(date),
        endDate: _isoDate(endDate),
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );
      return const Success(null);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _settingsMessage(e.response?.statusCode)),
      );
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not close this date.'),
      );
    }
  }

  String _settingsMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'Please check the highlighted fields and try again.',
      401 => 'Please sign in again to change these settings.',
      403 => 'You do not have permission to change these settings.',
      404 => 'We could not find this business.',
      409 => 'That URL slug is already taken. Please choose another.',
      413 => 'That image is too large. Please choose a smaller file.',
      422 => 'Please check the highlighted fields and try again.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not save your changes.',
    };
  }

  @override
  Future<Result<BusinessStats>> getBusinessStats({
    required String businessId,
    required String accessToken,
  }) async {
    try {
      final stats = await _remoteDataSource.getBusinessStats(
        businessId: businessId,
        accessToken: accessToken,
      );
      return Success(stats);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _statsMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load business stats.'),
      );
    }
  }

  @override
  Future<Result<List<MyBooking>>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  }) async {
    try {
      final bookings = await _remoteDataSource.getBusinessBookings(
        businessId: businessId,
        accessToken: accessToken,
        limit: limit,
      );
      return Success(bookings);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _bookingsMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load business bookings.'),
      );
    }
  }

  @override
  Future<Result<List<BusinessResource>>> getBusinessResources({
    required String businessId,
    required String accessToken,
  }) async {
    try {
      final resources = await _remoteDataSource.getBusinessResources(
        businessId: businessId,
        accessToken: accessToken,
      );
      return Success(resources);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load business venues.'),
      );
    }
  }

  @override
  Future<Result<List<ResourceCategory>>> getResourceCategories({
    required String businessId,
    required String accessToken,
  }) async {
    try {
      final categories = await _remoteDataSource.getResourceCategories(
        businessId: businessId,
        accessToken: accessToken,
      );
      return Success(categories);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load venue categories.'),
      );
    }
  }

  @override
  Future<Result<ResourceCategory>> createResourceCategory({
    required String businessId,
    required String accessToken,
    required String name,
    required String description,
  }) async {
    try {
      final category = await _remoteDataSource.createResourceCategory(
        businessId: businessId,
        accessToken: accessToken,
        name: name,
        description: description,
      );
      return Success(category);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not create this category.'),
      );
    }
  }

  @override
  Future<Result<BusinessResource>> createBusinessResource({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    try {
      final resource = await _remoteDataSource.createBusinessResource(
        businessId: businessId,
        accessToken: accessToken,
        fields: fields,
        imagePaths: imagePaths,
      );
      return Success(resource);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not create this venue.'),
      );
    }
  }

  @override
  Future<Result<BusinessResource>> updateBusinessResource({
    required String resourceId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    try {
      final resource = await _remoteDataSource.updateBusinessResource(
        resourceId: resourceId,
        accessToken: accessToken,
        fields: fields,
        imagePaths: imagePaths,
      );
      return Success(resource);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not update this venue.'),
      );
    }
  }

  @override
  Future<Result<void>> deleteBusinessResource({
    required String resourceId,
    required String accessToken,
  }) async {
    try {
      await _remoteDataSource.deleteBusinessResource(
        resourceId: resourceId,
        accessToken: accessToken,
      );
      return const Success<void>(null);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not delete this venue.'),
      );
    }
  }

  @override
  Future<Result<List<ScheduleException>>> getScheduleExceptions({
    required String businessId,
    required String accessToken,
  }) async {
    try {
      final exceptions = await _remoteDataSource.getScheduleExceptions(
        businessId: businessId,
        accessToken: accessToken,
      );
      return Success(exceptions);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load schedule exceptions.'),
      );
    }
  }

  @override
  Future<Result<ScheduleException>> createScheduleException({
    required String accessToken,
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  }) async {
    try {
      final exception = await _remoteDataSource.createScheduleException(
        accessToken: accessToken,
        resourceId: resourceId,
        date: date,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        isBlockout: isBlockout,
        reason: reason,
      );
      return Success(exception);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not create this schedule exception.'),
      );
    }
  }

  @override
  Future<Result<void>> deleteScheduleException({
    required String exceptionId,
    required String accessToken,
  }) async {
    try {
      await _remoteDataSource.deleteScheduleException(
        exceptionId: exceptionId,
        accessToken: accessToken,
      );
      return const Success<void>(null);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _resourcesMessage(e.response?.statusCode)));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not delete this exception.'),
      );
    }
  }

  @override
  Future<Result<void>> createManualBooking({
    required String accessToken,
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    num? overridePrice,
  }) async {
    try {
      await _remoteDataSource.createManualBooking(
        accessToken: accessToken,
        body: {
          'resourceId': resourceId,
          // The API works in UTC; sending the device's local wall clock would
          // shift every manual booking by the owner's offset.
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          'overridePrice': ?overridePrice,
          'customerDetails': {
            'firstName': firstName,
            'lastName': lastName,
            // Email is optional on this form; the server rejects an empty
            // string, so the key is dropped entirely when unset.
            if (email.isNotEmpty) 'email': email,
            'phone': phone,
          },
        },
      );
      return const Success<void>(null);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(
          message: _manualBookingMessage(e.response),
        ),
      );
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not create this booking.'),
      );
    }
  }

  /// The booking endpoint explains *why* a slot was refused (already booked,
  /// outside opening hours, and so on). Surfacing the server's own sentence is
  /// far more useful to an owner than a generic failure.
  String _manualBookingMessage(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.map((entry) => entry.toString()).join('\n');
      }
    }

    return switch (response?.statusCode) {
      400 => 'That booking was rejected. Check the venue, times and phone '
          'number, then try again.',
      401 => 'Please sign in again to create this booking.',
      403 => 'You do not have access to book this venue.',
      409 => 'That slot is already booked.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not create this booking.',
    };
  }

  @override
  Future<Result<BusinessPayments>> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    try {
      final payments = await _remoteDataSource.getBusinessPayments(
        businessId: businessId,
        accessToken: accessToken,
        startDate: _isoDate(startDate),
        endDate: _isoDate(endDate),
        limit: limit,
      );
      return Success(payments);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _paymentsMessage(e.response?.statusCode)),
      );
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load payments.'),
      );
    }
  }

  @override
  Future<Result<void>> updatePaymentStatus({
    required String paymentId,
    required String accessToken,
    required String status,
  }) async {
    try {
      await _remoteDataSource.updatePaymentStatus(
        paymentId: paymentId,
        accessToken: accessToken,
        status: status,
      );
      return const Success<void>(null);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _paymentWriteMessage(e.response?.statusCode)),
      );
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not update this payment.'),
      );
    }
  }

  @override
  Future<Result<void>> updatePaymentMethod({
    required String paymentId,
    required String accessToken,
    required String method,
  }) async {
    try {
      await _remoteDataSource.updatePaymentMethod(
        paymentId: paymentId,
        accessToken: accessToken,
        method: method,
      );
      return const Success<void>(null);
    } on DioException catch (e) {
      return Fail(
        ServerFailure(message: _paymentWriteMessage(e.response?.statusCode)),
      );
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not update the payment method.'),
      );
    }
  }

  String _paymentsMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please sign in again to view payments.',
      403 => 'You do not have access to these payments.',
      404 => 'Payments were not found for this business.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not load payments.',
    };
  }

  String _paymentWriteMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'That payment update was rejected. Please try again.',
      401 => 'Please sign in again to update this payment.',
      403 => 'You do not have access to this payment.',
      404 => 'That payment no longer exists.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not update this payment.',
    };
  }

  String _statsMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please sign in again to view business stats.',
      403 => 'You do not have access to these business stats.',
      404 => 'Business stats were not found.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not load business stats.',
    };
  }

  String _bookingsMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please sign in again to view business bookings.',
      403 => 'You do not have access to these bookings.',
      404 => 'Business bookings were not found.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not load business bookings.',
    };
  }

  String _resourcesMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please sign in again to view business venues.',
      403 => 'You do not have access to these venues.',
      404 => 'Business venues were not found.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not load business venues.',
    };
  }
}

/// The holiday endpoints expect calendar dates (`yyyy-MM-dd`), not timestamps.
String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
