import '../models/business_model.dart';
import 'booking_remote_data_source.dart';

class MockBookingRemoteDataSource implements BookingRemoteDataSource {
  const MockBookingRemoteDataSource();

  @override
  Future<List<BusinessModel>> searchBusinesses() async {
    return _businesses.map(BusinessModel.fromJson).toList(growable: false);
  }
}

const _businesses = <Map<String, dynamic>>[
  {
    'id': '664d0372-f926-459d-abd5-db2f19eaaac3',
    'name': 'gwrswfefw',
    'slug': 'hitter-champs',
    'description': null,
    'logoUrl': null,
    'coverUrl': null,
    'type': 'TIME_SLOT',
    'businessModel': 'VENUE_BASED',
    'city': 'Peshawar',
    'address': 'Bashirabad Pajjagi Rd near Judge Banglow',
    'settings': {
      'category': 'SPORTS_GROUND',
      'currency': 'PKR',
    },
    'ownerId': 'fd0751f7-bada-4abe-8d5a-141281f5b180',
    'createdAt': '2026-07-15T10:09:12.474Z',
    'updatedAt': '2026-07-15T10:09:12.474Z',
    'resources': [],
  },
];
