import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/features/auth/data/model/profile.dart';
import 'package:kcars/features/auth/data/model/role.dart';
import 'package:kcars/features/company/data/model/company.dart';
import 'package:kcars/features/listing/listing_service.dart';
import 'package:kcars/features/listing/listing_screens.dart';

Profile owner({String? kyc = 'approved', Company? company, bool? personal}) =>
    Profile(
      userId: 'owner',
      name: 'Owner',
      email: 'owner@example.com',
      phoneNumber: null,
      role: Role(roleName: 'user'),
      countryCode: null,
      permissions: [],
      kycStatus: kyc,
      company: company,
      isPersonal: personal,
    );

final catalogs = <String, List<JsonMap>>{
  'brands': [
    {'id': 'jeep', 'en': 'Jeep'},
    {'id': 'land-rover', 'en': 'Land Rover'},
  ],
  'types': [
    {'id': 'suv', 'en': 'SUV'},
  ],
  'plans': [
    {'id': 'daily', 'periodType': 'daily'},
    {'id': 'monthly', 'periodType': 'monthly'},
  ],
  'seatId': [
    {'id': 'seat7', 'en': '7'},
  ],
  'hpId': [
    {'id': 'hp290', 'en': '290 hp'},
  ],
  'engCCId': [
    {'id': 'cc36', 'en': '3.6 L'},
  ],
};

ListingDraft validDraft() => ListingDraft()
  ..title = 'Jeep Grand Cherokee'
  ..brandId = 'jeep'
  ..photos.add(ListingPhoto.remote({'id': 'photo', 'image': null}))
  ..plans.add({'periodType': 'daily', 'price': '50', 'currency': 'usd'});

JsonMap existingCar() => {
  'id': 'car',
  'title': 'Jeep Grand Cherokee',
  'brandId': 'jeep',
  'available': false,
  'displayPlan': 'daily',
  'feature': {
    'year': 2021,
    'extras': {
      'vin': '1C4RJFAG0FC123456',
      'amenities': ['rear_camera'],
    },
  },
  'images': [
    {'id': 'photo', 'image': null, 'sort': 0},
  ],
  'rentalPlan': [
    {
      'id': 'old-plan',
      'planId': 'daily',
      'periodType': 'daily',
      'price': 50,
      'currency': 'usd',
    },
  ],
};

class RecordingApi implements ApiService {
  final calls = <MapEntry<String, Object?>>[];
  @override
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromMap,
    Function(int, int)? onSendProgress,
  }) async {
    calls.add(MapEntry(path, data));
    return null as T;
  }
}

class FakeListingService extends ListingService {
  FakeListingService() : super(RecordingApi());
  @override
  Future<Map<String, List<JsonMap>>> catalogs() async => Map.fromEntries(
    listingCatalogPaths.keys.map((key) => MapEntry(key, testCatalog(key))),
  );
  List<JsonMap> testCatalog(String key) => catalogsFixture[key] ?? [];
  @override
  Future<Profile> refreshProfile() async => owner();
  @override
  Future<String?> save(
    ListingDraft draft,
    Map<String, List<JsonMap>> catalogs,
    Profile profile,
  ) async => null;
}

final catalogsFixture = catalogs;

void main() {
  test('posting is restricted to verified personal owners or companies', () {
    expect(canManageListings(null), isFalse);
    expect(canManageListings(owner(kyc: 'pending')), isFalse);
    expect(canManageListings(owner()), isTrue);
    expect(
      canManageListings(
        owner(
          kyc: null,
          company: Company(id: 'company', name: 'Rental company'),
        ),
      ),
      isTrue,
    );
    expect(
      canManageListings(
        owner(
          kyc: 'pending',
          company: Company(id: 'personal', name: 'Owner · Personal Cars'),
        ),
      ),
      isFalse,
    );
    expect(
      canManageListings(
        owner(
          kyc: 'pending',
          personal: true,
          company: Company(id: 'personal', name: 'Owner'),
        ),
      ),
      isFalse,
    );
  });

  test('personal list never sends an unscoped company query', () async {
    final api = RecordingApi();
    expect(await ListingService(api).cars(owner()), isEmpty);
    expect(api.calls, isEmpty);
    await ListingService(api).cars(
      owner(
        company: Company(id: 'company', name: 'Rental'),
      ),
    );
    expect((api.calls.single.value as Map)['companyId'], 'company');
  });

  test(
    'AI matches exact brand, units, and capacity without guessing unknown options',
    () {
      final draft = ListingDraft();
      final warnings = draft.applyRecognition({
        'brandName': 'Jeep',
        'model': 'Grand Cherokee L',
        'year': 2021,
        'vehicleType': 'SUV',
        'seats': 7,
        'horsePower': 290,
        'engineCapacity': 3600,
        'speed': 250,
        'features': ['rear_camera', 'made_up_feature'],
      }, catalogs);
      expect(draft.title, 'Jeep Grand Cherokee L');
      expect(draft.brandId, 'jeep');
      expect(draft.year, '2021');
      expect(draft.specIds['seatId'], 'seat7');
      expect(draft.specIds['hpId'], 'hp290');
      expect(draft.specIds['engCCId'], 'cc36');
      expect(draft.amenities, {'rear_camera'});
      expect(warnings.single, contains('Top speed'));
      expect(matchListingCatalog(catalogs['brands']!, 'Land'), isNull);
      draft.applyRecognition({
        'brandName': null,
        'year': null,
        'model': null,
      }, catalogs);
      expect(draft.brandId, 'jeep');
      expect(draft.year, '2021');
    },
  );

  test(
    'validates prices, duplicate periods, gallery limits and optional VIN',
    () {
      final draft = validDraft();
      expect(draft.validate(catalogs), isNull);
      for (final price in ['0', '-1', 'NaN', 'Infinity', 'invalid']) {
        draft.plans.first['price'] = price;
        expect(draft.validate(catalogs), contains('price'));
      }
      draft.plans.first['price'] = '1,200';
      expect(draft.validate(catalogs), isNull);
      draft.plans.add(Map.from(draft.plans.first));
      expect(draft.validate(catalogs), contains('only once'));
      draft.plans.removeLast();
      draft.vin = 'invalid';
      expect(draft.validate(catalogs), contains('VIN'));
      draft.vin = '';
      draft.photos.clear();
      expect(draft.validate(catalogs), contains('photo'));
    },
  );

  test(
    'new personal car is unavailable; company car is published; VIN photo never serialized',
    () async {
      final draft = validDraft()
        ..vinPhoto = File('private-vin.jpg')
        ..vin = '1C4RJFAG0FC123456';
      draft.photos
        ..clear()
        ..add(ListingPhoto.local(File('assets/images/carva.png')));
      final fields = draft.fields(catalogs, personal: true);
      expect(fields['available'], 'false');
      expect(draft.fields(catalogs, personal: false)['available'], 'true');
      expect(jsonDecode(fields['feature'])['extras']['vin'], draft.vin);
      expect(jsonEncode(fields), isNot(contains('private-vin.jpg')));
      final api = RecordingApi();
      await ListingService(api).save(draft, catalogs, owner());
      expect(api.calls.single.key, '/company/car/new');
      final files = (api.calls.single.value as FormData).files;
      expect(files.single.key, 'images');
      expect(files.single.value.filename, 'carva.png');
    },
  );

  test(
    'rental price edit replaces only changed plan, does not overwrite approval',
    () {
      final draft = ListingDraft(original: existingCar());
      expect(
        draft.fields(catalogs, personal: true).containsKey('rentalPlan'),
        isFalse,
      );
      draft.plans.first['price'] = '75';
      final fields = draft.fields(catalogs, personal: true);
      expect(jsonDecode(fields['deletedRentalPlans']), [
        {'id': 'old-plan'},
      ]);
      final plans = jsonDecode(fields['rentalPlan']) as List;
      expect(plans.single['price'], 75);
      expect(plans.single['planId'], 'daily');
      expect(plans.single['available'], true);
      expect(fields.containsKey('available'), isFalse);
    },
  );

  test(
    'first image order is preserved and removed images are explicitly identified',
    () {
      final original = existingCar();
      original['images'] = [
        {'id': 'second', 'image': 'second.jpg', 'sort': 1},
        {'id': 'first', 'image': 'first.jpg', 'sort': 0},
      ];
      final draft = ListingDraft(original: original);
      expect(draft.photos.first.existing!['id'], 'first');
      draft.photos.removeAt(0);
      expect(
        jsonDecode(draft.fields(catalogs, personal: true)['deletedImages']),
        [
          {'id': 'first', 'image': 'first.jpg'},
        ],
      );
    },
  );

  testWidgets(
    'two-step editor hides VIN in details and keeps editable features/prices/photos',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ListingEditor(
              profile: owner(),
              original: existingCar(),
              service: FakeListingService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VIN • optional'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Fill in details manually'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Fill in details manually'));
      await tester.pumpAndSettle();
      expect(find.text('VIN • optional'), findsNothing);
      expect(find.text('Type VIN (optional)'), findsNothing);
      expect(find.text('Car details'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Listing photos'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      expect(find.text('Listing photos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rental prices'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rental prices'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save changes'),
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
