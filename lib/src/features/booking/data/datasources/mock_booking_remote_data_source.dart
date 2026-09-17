import '../models/business_category_model.dart';
import '../models/business_model.dart';
import '../models/booking_confirmation_model.dart';
import '../models/my_booking_model.dart';
import '../models/review_model.dart';
import '../models/slot_availability_model.dart';
import 'booking_remote_data_source.dart';

class MockBookingRemoteDataSource implements BookingRemoteDataSource {
  const MockBookingRemoteDataSource();

  @override
  Future<List<BusinessModel>> searchBusinesses({
    String query = '',
    String category = '',
  }) async {
    // The mock fixture is a single business, so filters are not applied — good
    // enough for the offline/dev flow this data source exists for.
    return _businesses.map(BusinessModel.fromJson).toList(growable: false);
  }

  @override
  Future<List<BusinessCategoryModel>> getCategories() async {
    return const [
      BusinessCategoryModel(value: 'SPORTS_GROUND', label: 'Sports Ground'),
      BusinessCategoryModel(value: 'SALON', label: 'Salon'),
      BusinessCategoryModel(value: 'CLINIC', label: 'Clinic'),
    ];
  }

  @override
  Future<BusinessModel> getBusinessBySlug(String slug) async {
    final business = _businesses.firstWhere(
      (item) => item['slug'] == slug,
      orElse: () => _businesses.first,
    );

    return BusinessModel.fromJson(business);
  }

  @override
  Future<List<SlotAvailabilityModel>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  }) async {
    return _availability
        .map(SlotAvailabilityModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<BookingConfirmationModel> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  }) async {
    return BookingConfirmationModel.fromJson({
      'id': 'mock-booking',
      'resourceId': resourceId,
      'slots': slots,
      'paymentMethod': paymentMethod,
      'customerDetails': customerDetails,
    });
  }

  @override
  Future<List<MyBookingModel>> getMyBookings(String accessToken) async {
    return _myBookings.map(MyBookingModel.fromJson).toList(growable: false);
  }

  @override
  Future<void> cancelBooking({
    required String accessToken,
    required String bookingId,
  }) async {}

  @override
  Future<List<ReviewModel>> getBusinessReviews(String businessId) async {
    return const [];
  }

  @override
  Future<List<MyBookingModel>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  }) async {
    return _myBookings.map(MyBookingModel.fromJson).toList(growable: false);
  }

  @override
  Future<ReviewModel> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    return ReviewModel(
      id: 'mock-review',
      rating: rating,
      comment: comment,
      customerName: 'You',
      createdAt: DateTime.now(),
    );
  }
}

const _businesses = <Map<String, dynamic>>[
  {
    'id': '664d0372-f926-459d-abd5-db2f19eaaac3',
    'name': 'gwrswfefw',
    'slug': 'hitter-champs',
    'description': null,
    'logoUrl': '/uploads/businesses/1784288086791-234768820.jpg',
    'coverUrl': '/uploads/businesses/1784288086793-209691319.jpg',
    'type': 'TIME_SLOT',
    'businessModel': 'VENUE_BASED',
    'city': 'Peshawar',
    'address': 'Bashirabad Pajjagi Rd near Judge Banglow',
    'settings': {
      'currency': 'PKR',
      'operatingHours': [
        {
          'endTime': '00:00',
          'isOffDay': false,
          'dayOfWeek': 1,
          'startTime': '09:00',
        },
      ],
    },
    'ownerId': 'fd0751f7-bada-4abe-8d5a-141281f5b180',
    'createdAt': '2026-07-15T10:09:12.474Z',
    'updatedAt': '2026-07-15T10:09:12.474Z',
    'resources': [
      {
        'id': 'bf72c5f9-fe4f-4a62-924a-b2e97db7670b',
        'name': 'L Field',
        'basePrice': 2500,
        'isActive': true,
      },
      {
        'id': '03cf283c-38b5-44c0-8070-0a0325efced2',
        'name': 'Main Field',
        'basePrice': 3500,
        'isActive': true,
      },
      {
        'id': '8c8fbdf5-1454-401d-a833-67b035d83402',
        'name': 'R field',
        'basePrice': 2500,
        'isActive': true,
      },
    ],
  },
];

const _availability = <Map<String, dynamic>>[
  {'time': '09:00 AM', 'available': true},
  {'time': '10:00 AM', 'available': true},
  {'time': '11:00 AM', 'available': true},
  {'time': '12:00 PM', 'available': true},
  {'time': '01:00 PM', 'available': true},
  {'time': '02:00 PM', 'available': true},
  {'time': '03:00 PM', 'available': true},
  {'time': '04:00 PM', 'available': true},
  {'time': '05:00 PM', 'available': true},
  {'time': '06:00 PM', 'available': true},
  {'time': '07:00 PM', 'available': true},
  {'time': '08:00 PM', 'available': true},
  {'time': '09:00 PM', 'available': true},
  {'time': '10:00 PM', 'available': true},
  {'time': '11:00 PM', 'available': true},
];

const _myBookings = <Map<String, dynamic>>[
  {
    'id': 'mock-booking-1',
    'status': 'PENDING',
    'totalAmount': 2500,
    'business': {
      'name': 'Bats and Balls',
      'settings': {'currency': 'PKR'},
    },
    'resource': {'name': 'L Field'},
    'slots': ['2026-07-20T15:00:00.000Z'],
  },
];
