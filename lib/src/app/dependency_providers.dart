import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/network.dart';
import '../core/notifications/fcm_token_service.dart';
import '../core/notifications/notification_token_registration_service.dart';
import '../features/auth/data/datasources/auth_local_data_source.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/dio_auth_remote_data_source.dart';
import '../features/auth/data/datasources/google_identity_service.dart';
import '../features/auth/data/datasources/shared_preferences_auth_local_data_source.dart';
import '../features/auth/data/models/auth_session_model.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_user.dart';
import '../features/auth/domain/usecases/register_user.dart';
import '../features/auth/domain/usecases/logout_user.dart';
import '../features/auth/domain/usecases/refresh_session.dart';
import '../features/auth/domain/usecases/request_password_reset.dart';
import '../features/auth/domain/usecases/reset_password.dart';
import '../features/auth/domain/usecases/sign_in_with_google.dart';
import '../features/auth/domain/usecases/verify_otp.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/business_admin/data/datasources/business_admin_remote_data_source.dart';
import '../features/business_admin/data/datasources/dio_business_admin_remote_data_source.dart';
import '../features/business_admin/data/repositories/business_admin_repository_impl.dart';
import '../features/business_admin/domain/repositories/business_admin_repository.dart';
import '../features/business_admin/domain/usecases/check_holiday_bookings.dart';
import '../features/business_admin/domain/usecases/create_business_holiday.dart';
import '../features/business_admin/domain/usecases/create_business_resource.dart';
import '../features/business_admin/domain/usecases/create_resource_category.dart';
import '../features/business_admin/domain/usecases/create_schedule_exception.dart';
import '../features/business_admin/domain/usecases/delete_business_resource.dart';
import '../features/business_admin/domain/usecases/delete_schedule_exception.dart';
import '../features/business_admin/domain/usecases/get_business_bookings.dart';
import '../features/business_admin/domain/usecases/get_business_resources.dart';
import '../features/business_admin/domain/usecases/get_business_stats.dart';
import '../features/business_admin/domain/usecases/get_resource_categories.dart';
import '../features/business_admin/domain/usecases/create_manual_booking.dart';
import '../features/business_admin/domain/usecases/get_business_payments.dart';
import '../features/business_admin/domain/usecases/get_schedule_exceptions.dart';
import '../features/business_admin/domain/usecases/update_booking_status.dart';
import '../features/business_admin/domain/usecases/update_payment.dart';
import '../features/business_admin/domain/usecases/update_business.dart';
import '../features/business_admin/domain/usecases/update_business_resource.dart';
import '../features/business_admin/domain/usecases/update_operating_hours.dart';
import '../features/booking/data/datasources/booking_remote_data_source.dart';
import '../features/booking/data/datasources/dio_booking_remote_data_source.dart';
import '../features/booking/data/datasources/mock_booking_remote_data_source.dart';
import '../features/booking/data/repositories/booking_repository_impl.dart';
import '../features/booking/domain/repositories/booking_repository.dart';
import '../features/booking/domain/usecases/cancel_booking.dart';
import '../features/booking/domain/usecases/create_booking.dart';
import '../features/booking/domain/usecases/create_review.dart';
import '../features/booking/domain/usecases/get_availability.dart';
import '../features/booking/domain/usecases/get_business_by_slug.dart';
import '../features/booking/domain/usecases/get_business_categories.dart';
import '../features/booking/domain/usecases/get_business_reviews.dart';
import '../features/booking/domain/usecases/get_eligible_review_bookings.dart';
import '../features/booking/domain/usecases/get_my_bookings.dart';
import '../features/booking/domain/usecases/search_businesses.dart';

final useMockDataProvider = Provider<bool>((_) => AppConfig.useMockData);

final dioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.create();
  // A separate bare client for the refresh call itself, so refreshing a token
  // never re-enters this same interceptor.
  final refreshDio = DioFactory.create();

  dio.interceptors.add(
    AuthInterceptor(
      readTokens: () async {
        final session = await ref.read(authLocalDataSourceProvider).readSession();
        if (session == null) {
          return null;
        }
        return StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      },
      onTokensRefreshed: (tokens) async {
        final localDataSource = ref.read(authLocalDataSourceProvider);
        final current = await localDataSource.readSession();
        if (current == null) {
          return;
        }

        final refreshed = current.copyWith(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken.isEmpty
              // Some servers only reissue the access token; keeping the old
              // refresh token is better than blanking it.
              ? current.refreshToken
              : tokens.refreshToken,
        );

        await localDataSource.saveSession(
          AuthSessionModel.fromEntity(refreshed),
        );
        // Storage alone is not enough: every data source reads the token off
        // the in-memory session, so without this the app keeps sending the
        // token that just expired and pays a 401 plus a refresh on every
        // single call until it is restarted.
        ref.read(authControllerProvider.notifier).applyRefreshedSession(
              refreshed,
            );
      },
      onSessionExpired: () async {
        await ref.read(authLocalDataSourceProvider).clearSession();
        ref.read(authControllerProvider.notifier).forceSignOut();
      },
      refreshDio: refreshDio,
      retryDio: dio,
    ),
  );

  ref.onDispose(dio.close);
  ref.onDispose(refreshDio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('SharedPreferences must be provided at app startup.');
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((_) {
  return FirebaseMessaging.instance;
});

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService(ref.watch(firebaseMessagingProvider));
});

final fcmDeviceTokenProvider = FutureProvider<String?>((ref) {
  return ref.watch(fcmTokenServiceProvider).getDeviceToken();
});

final fcmTokenRefreshProvider = StreamProvider<String>((ref) {
  return ref.watch(fcmTokenServiceProvider).onTokenRefresh;
});

final notificationTokenRegistrationServiceProvider =
    Provider<NotificationTokenRegistrationService>((ref) {
  return NotificationTokenRegistrationService(ref.watch(apiClientProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return DioAuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return SharedPreferencesAuthLocalDataSource(
    ref.watch(sharedPreferencesProvider),
  );
});

final googleIdentityServiceProvider = Provider<GoogleIdentityService>((_) {
  return FirebaseGoogleIdentityService(
    serverClientId: AppConfig.googleServerClientId,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    googleIdentityService: ref.watch(googleIdentityServiceProvider),
  );
});

final registerUserProvider = Provider<RegisterUser>((ref) {
  return RegisterUser(ref.watch(authRepositoryProvider));
});

final verifyOtpProvider = Provider<VerifyOtp>((ref) {
  return VerifyOtp(ref.watch(authRepositoryProvider));
});

final loginUserProvider = Provider<LoginUser>((ref) {
  return LoginUser(ref.watch(authRepositoryProvider));
});

final signInWithGoogleProvider = Provider<SignInWithGoogle>((ref) {
  return SignInWithGoogle(ref.watch(authRepositoryProvider));
});

final logoutUserProvider = Provider<LogoutUser>((ref) {
  return LogoutUser(ref.watch(authRepositoryProvider));
});

final refreshSessionProvider = Provider<RefreshSession>((ref) {
  return RefreshSession(ref.watch(authRepositoryProvider));
});

final requestPasswordResetProvider = Provider<RequestPasswordReset>((ref) {
  return RequestPasswordReset(ref.watch(authRepositoryProvider));
});

final resetPasswordProvider = Provider<ResetPassword>((ref) {
  return ResetPassword(ref.watch(authRepositoryProvider));
});

final bookingRemoteDataSourceProvider = Provider<BookingRemoteDataSource>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return const MockBookingRemoteDataSource();
  }

  return DioBookingRemoteDataSource(ref.watch(apiClientProvider));
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl(ref.watch(bookingRemoteDataSourceProvider));
});

final searchBusinessesProvider = Provider<SearchBusinesses>((ref) {
  return SearchBusinesses(ref.watch(bookingRepositoryProvider));
});

final getBusinessBySlugProvider = Provider<GetBusinessBySlug>((ref) {
  return GetBusinessBySlug(ref.watch(bookingRepositoryProvider));
});

final getAvailabilityProvider = Provider<GetAvailability>((ref) {
  return GetAvailability(ref.watch(bookingRepositoryProvider));
});

final createBookingProvider = Provider<CreateBooking>((ref) {
  return CreateBooking(ref.watch(bookingRepositoryProvider));
});

final getMyBookingsProvider = Provider<GetMyBookings>((ref) {
  return GetMyBookings(ref.watch(bookingRepositoryProvider));
});

final getBusinessCategoriesProvider = Provider<GetBusinessCategories>((ref) {
  return GetBusinessCategories(ref.watch(bookingRepositoryProvider));
});

final cancelBookingProvider = Provider<CancelBooking>((ref) {
  return CancelBooking(ref.watch(bookingRepositoryProvider));
});

final getBusinessReviewsProvider = Provider<GetBusinessReviews>((ref) {
  return GetBusinessReviews(ref.watch(bookingRepositoryProvider));
});

final getEligibleReviewBookingsProvider =
    Provider<GetEligibleReviewBookings>((ref) {
  return GetEligibleReviewBookings(ref.watch(bookingRepositoryProvider));
});

final createReviewProvider = Provider<CreateReview>((ref) {
  return CreateReview(ref.watch(bookingRepositoryProvider));
});

final businessAdminRemoteDataSourceProvider =
    Provider<BusinessAdminRemoteDataSource>((ref) {
  return DioBusinessAdminRemoteDataSource(ref.watch(apiClientProvider));
});

final businessAdminRepositoryProvider = Provider<BusinessAdminRepository>((ref) {
  return BusinessAdminRepositoryImpl(
    ref.watch(businessAdminRemoteDataSourceProvider),
  );
});

final getBusinessStatsProvider = Provider<GetBusinessStats>((ref) {
  return GetBusinessStats(ref.watch(businessAdminRepositoryProvider));
});

final updateBusinessProvider = Provider<UpdateBusiness>((ref) {
  return UpdateBusiness(ref.watch(businessAdminRepositoryProvider));
});

final updateOperatingHoursProvider = Provider<UpdateOperatingHours>((ref) {
  return UpdateOperatingHours(ref.watch(businessAdminRepositoryProvider));
});

final checkHolidayBookingsProvider = Provider<CheckHolidayBookings>((ref) {
  return CheckHolidayBookings(ref.watch(businessAdminRepositoryProvider));
});

final createBusinessHolidayProvider = Provider<CreateBusinessHoliday>((ref) {
  return CreateBusinessHoliday(ref.watch(businessAdminRepositoryProvider));
});

final getBusinessBookingsProvider = Provider<GetBusinessBookings>((ref) {
  return GetBusinessBookings(ref.watch(businessAdminRepositoryProvider));
});

final getBusinessResourcesProvider = Provider<GetBusinessResources>((ref) {
  return GetBusinessResources(ref.watch(businessAdminRepositoryProvider));
});

final getResourceCategoriesProvider = Provider<GetResourceCategories>((ref) {
  return GetResourceCategories(ref.watch(businessAdminRepositoryProvider));
});

final createResourceCategoryProvider = Provider<CreateResourceCategory>((ref) {
  return CreateResourceCategory(ref.watch(businessAdminRepositoryProvider));
});

final createBusinessResourceProvider = Provider<CreateBusinessResource>((ref) {
  return CreateBusinessResource(ref.watch(businessAdminRepositoryProvider));
});

final updateBusinessResourceProvider = Provider<UpdateBusinessResource>((ref) {
  return UpdateBusinessResource(ref.watch(businessAdminRepositoryProvider));
});

final deleteBusinessResourceProvider = Provider<DeleteBusinessResource>((ref) {
  return DeleteBusinessResource(ref.watch(businessAdminRepositoryProvider));
});

final getScheduleExceptionsProvider = Provider<GetScheduleExceptions>((ref) {
  return GetScheduleExceptions(ref.watch(businessAdminRepositoryProvider));
});

final createScheduleExceptionProvider = Provider<CreateScheduleException>((ref) {
  return CreateScheduleException(ref.watch(businessAdminRepositoryProvider));
});

final deleteScheduleExceptionProvider = Provider<DeleteScheduleException>((ref) {
  return DeleteScheduleException(ref.watch(businessAdminRepositoryProvider));
});

final updateBookingStatusProvider = Provider<UpdateBookingStatus>((ref) {
  return UpdateBookingStatus(ref.watch(businessAdminRepositoryProvider));
});

final createManualBookingProvider = Provider<CreateManualBooking>((ref) {
  return CreateManualBooking(ref.watch(businessAdminRepositoryProvider));
});

final getBusinessPaymentsProvider = Provider<GetBusinessPayments>((ref) {
  return GetBusinessPayments(ref.watch(businessAdminRepositoryProvider));
});

final updatePaymentProvider = Provider<UpdatePayment>((ref) {
  return UpdatePayment(ref.watch(businessAdminRepositoryProvider));
});
