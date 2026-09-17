class ApiEndpoints {
  const ApiEndpoints._();

  static const authRegister = '/auth/register';
  static const authVerifyOtp = '/auth/verify-otp';
  static const authLogin = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authForgotPassword = '/auth/forgot-password';
  static const authResetPassword = '/auth/reset-password';

  static const businessesSearch = '/businesses/search';
  static const publicBookingAvailability = '/public/bookings/availability';
  static const bookings = '/bookings';
  static const myBookings = '/bookings/my-bookings';
  static const notificationToken = '/notifications/token';
  static const configCategories = '/config/categories';
  static const reviews = '/reviews';

  static String bookingCancel(String bookingId) {
    return '/bookings/$bookingId/cancel';
  }

  static String businessReviews(String businessId) {
    return '/reviews/business/$businessId';
  }

  static String eligibleReviewBookings(String businessId) {
    return '/reviews/eligible-bookings/$businessId';
  }

  static String businessBySlug(String slug) {
    return '/businesses/$slug';
  }

  static String businessStats(String businessId) {
    return '/businesses/$businessId/stats';
  }

  static String businessById(String businessId) {
    return '/businesses/$businessId';
  }

  static String businessOperatingHours(String businessId) {
    return '/businesses/$businessId/operating-hours';
  }

  static String businessHolidays(String businessId) {
    return '/businesses/$businessId/holidays';
  }

  static String businessHolidayCheckBookings(String businessId) {
    return '/businesses/$businessId/holidays/check-bookings';
  }

  static String businessBookings(String businessId) {
    return '/bookings/business/$businessId';
  }

  static String businessResources(String businessId) {
    return '/resources/business/$businessId';
  }

  static const resourceCategories = '/resource-categories';

  static String resourceCategoriesByBusiness(String businessId) {
    return '/resource-categories/business/$businessId';
  }

  static String resourceById(String resourceId) {
    return '/resources/$resourceId';
  }

  static String notificationTokenByToken(String token) {
    return '/notifications/token/${Uri.encodeComponent(token)}';
  }

  static String businessPayments(String businessId) {
    return '/payments/business/$businessId';
  }

  /// Body: `{"status": "PAID" | "PENDING" | "FAILED" | "REFUNDED"}`.
  static String paymentStatus(String paymentId) {
    return '/payments/$paymentId/status';
  }

  /// Body: `{"method": "<free-form string>"}` — the server does not constrain
  /// this to an enum.
  static String paymentMethod(String paymentId) {
    return '/payments/$paymentId/method';
  }

  static const scheduleExceptions = '/schedule-exceptions';

  static String scheduleExceptionsByBusiness(String businessId) {
    return '/schedule-exceptions/business/$businessId';
  }

  static String scheduleExceptionById(String id) {
    return '/schedule-exceptions/$id';
  }
}
