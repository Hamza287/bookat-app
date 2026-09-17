import '../../../../core/utils/result.dart';
import '../entities/booking_confirmation.dart';
import '../entities/business.dart';
import '../entities/business_category.dart';
import '../entities/my_booking.dart';
import '../entities/review.dart';
import '../entities/slot_availability.dart';

abstract interface class BookingRepository {
  Future<Result<List<Business>>> searchBusinesses({
    String query = '',
    String category = '',
  });

  Future<Result<List<BusinessCategory>>> getCategories();

  Future<Result<Business>> getBusinessBySlug(String slug);

  Future<Result<List<SlotAvailability>>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  });

  Future<Result<BookingConfirmation>> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  });

  Future<Result<List<MyBooking>>> getMyBookings(String accessToken);

  Future<Result<void>> cancelBooking({
    required String accessToken,
    required String bookingId,
  });

  Future<Result<List<Review>>> getBusinessReviews(String businessId);

  Future<Result<List<MyBooking>>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  });

  Future<Result<Review>> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  });
}
