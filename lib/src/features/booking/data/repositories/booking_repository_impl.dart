import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/booking_confirmation.dart';
import '../../domain/entities/business.dart';
import '../../domain/entities/business_category.dart';
import '../../domain/entities/my_booking.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/slot_availability.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._remoteDataSource);

  final BookingRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<Business>>> searchBusinesses({
    String query = '',
    String category = '',
  }) async {
    try {
      final businesses = await _remoteDataSource.searchBusinesses(
        query: query,
        category: category,
      );
      return Success(businesses);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<BusinessCategory>>> getCategories() async {
    try {
      final categories = await _remoteDataSource.getCategories();
      return Success(categories);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Business>> getBusinessBySlug(String slug) async {
    try {
      final business = await _remoteDataSource.getBusinessBySlug(slug);
      return Success(business);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<SlotAvailability>>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  }) async {
    try {
      final slots = await _remoteDataSource.getAvailability(
        resourceId: resourceId,
        date: date,
        tzOffset: tzOffset,
      );
      return Success(slots);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<BookingConfirmation>> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  }) async {
    try {
      final booking = await _remoteDataSource.createBooking(
        accessToken: accessToken,
        resourceId: resourceId,
        slots: slots,
        paymentMethod: paymentMethod,
        customerDetails: customerDetails,
      );
      return Success(booking);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _bookingMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not create this booking.'),
      );
    }
  }

  String _bookingMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'Please select a valid slot and try again.',
      401 => 'Please sign in again before booking.',
      409 => 'This slot was just booked. Please choose another time.',
      422 => 'Please check your booking details and try again.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not create this booking.',
    };
  }

  @override
  Future<Result<List<MyBooking>>> getMyBookings(String accessToken) async {
    try {
      final bookings = await _remoteDataSource.getMyBookings(accessToken);
      return Success(bookings);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _myBookingsMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not load your bookings.'),
      );
    }
  }

  String _myBookingsMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please sign in again to view your bookings.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not load your bookings.',
    };
  }

  @override
  Future<Result<void>> cancelBooking({
    required String accessToken,
    required String bookingId,
  }) async {
    try {
      await _remoteDataSource.cancelBooking(
        accessToken: accessToken,
        bookingId: bookingId,
      );
      return const Success(null);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _cancelMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not cancel this booking.'),
      );
    }
  }

  String _cancelMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'This booking can no longer be cancelled.',
      401 => 'Please sign in again to cancel this booking.',
      403 =>
        'This booking is outside the venue\'s cancellation window and can no longer be cancelled.',
      404 => 'This booking could not be found.',
      409 => 'This booking can no longer be cancelled.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not cancel this booking.',
    };
  }

  @override
  Future<Result<List<Review>>> getBusinessReviews(String businessId) async {
    try {
      final reviews = await _remoteDataSource.getBusinessReviews(businessId);
      return Success(reviews);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<MyBooking>>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  }) async {
    try {
      final bookings = await _remoteDataSource.getEligibleReviewBookings(
        accessToken: accessToken,
        businessId: businessId,
      );
      return Success(bookings);
    } on DioException catch (e) {
      return Fail(NetworkFailure(message: e.message ?? 'Network error'));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (e) {
      return Fail(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Review>> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final review = await _remoteDataSource.createReview(
        accessToken: accessToken,
        businessId: businessId,
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      );
      return Success(review);
    } on DioException catch (e) {
      return Fail(ServerFailure(message: _reviewMessage(e.response?.statusCode)));
    } on FormatException catch (e) {
      return Fail(ServerFailure(message: e.message));
    } catch (_) {
      return const Fail(
        UnexpectedFailure(message: 'We could not submit your review.'),
      );
    }
  }

  String _reviewMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'Please check your review and try again.',
      401 => 'Please sign in again to leave a review.',
      409 => 'You have already reviewed this booking.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'We could not submit your review.',
    };
  }
}
