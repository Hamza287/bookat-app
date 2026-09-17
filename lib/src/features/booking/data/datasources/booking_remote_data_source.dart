import '../models/business_category_model.dart';
import '../models/business_model.dart';
import '../models/booking_confirmation_model.dart';
import '../models/my_booking_model.dart';
import '../models/review_model.dart';
import '../models/slot_availability_model.dart';

abstract interface class BookingRemoteDataSource {
  Future<List<BusinessModel>> searchBusinesses({
    String query = '',
    String category = '',
  });

  Future<List<BusinessCategoryModel>> getCategories();

  Future<BusinessModel> getBusinessBySlug(String slug);

  Future<List<SlotAvailabilityModel>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  });

  Future<BookingConfirmationModel> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  });

  Future<List<MyBookingModel>> getMyBookings(String accessToken);

  Future<void> cancelBooking({
    required String accessToken,
    required String bookingId,
  });

  Future<List<ReviewModel>> getBusinessReviews(String businessId);

  Future<List<MyBookingModel>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  });

  Future<ReviewModel> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  });
}
