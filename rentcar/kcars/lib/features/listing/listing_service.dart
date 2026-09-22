import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:kcars/configs/error/exception.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/features/auth/data/model/profile.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap listingMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<JsonMap> listingList(dynamic value) {
  final data = value is Map ? value['data'] ?? value['cars'] : value;
  return data is List ? data.whereType<Map>().map(listingMap).toList() : [];
}

bool personalOwner(Profile user) =>
    user.isPersonal == true ||
    user.company == null ||
    user.company!.name.endsWith(' · Personal Cars');
bool canManageListings(Profile? user) =>
    user != null &&
    (!personalOwner(user) ||
        user.kycStatus?.trim().toLowerCase() == 'approved');

const listingAmenities = <String, String>{
  'parking_sensors': 'Parking sensors',
  'apple_carplay': 'Apple CarPlay',
  'android_auto': 'Android Auto',
  'rear_camera': 'Rear camera',
  'cruise_control': 'Cruise control',
  'adaptive_cruise': 'Adaptive cruise control',
  'infotainment_screen': 'Touchscreen',
  'smart_key': 'Smart key',
  'blind_spot_monitor': 'Blind spot monitor',
  'lane_assist': 'Lane assist',
  'automatic_emergency_braking': 'Automatic emergency braking',
  'bluetooth': 'Bluetooth',
  'usb': 'USB charging',
  'heated_seats': 'Heated seats',
  'climate_control': 'Climate control',
  'sunroof': 'Sunroof',
  'all_wheel_drive': 'All-wheel drive',
};
const listingCatalogPaths = <String, String>{
  'brands': 'brands',
  'types': 'carTypes',
  'plans': 'plans',
  'seatId': 'carSeats',
  'hpId': 'carHorsePowers',
  'speedId': 'carSpeeds',
  'odometerId': 'carOdometers',
  'cylindersId': 'carCylinders',
  'engCCId': 'carCapacityLiters',
};
const listingSpecLabels = <String, String>{
  'seatId': 'Seats',
  'hpId': 'Horsepower',
  'speedId': 'Top speed',
  'odometerId': 'Odometer',
  'cylindersId': 'Cylinders',
  'engCCId': 'Engine capacity',
};

String catalogText(JsonMap item, [String locale = 'en']) =>
    '${item[locale] ?? item['en'] ?? item['name'] ?? item['periodType'] ?? ''}';
String normalizedLabel(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]'), '');
String? matchListingCatalog(List<JsonMap> items, dynamic value) {
  final needle = normalizedLabel('$value');
  if (value == null || needle.isEmpty) return null;
  // Exact aliases only: "Land Rover" must not accidentally match "Land".
  for (final item in items) {
    if (['en', 'ar', 'ku'].any(
      (key) => item[key] != null && normalizedLabel('${item[key]}') == needle,
    )) {
      return '${item['id']}';
    }
  }
  return null;
}

class ListingPhoto {
  ListingPhoto.local(this.file) : existing = null;
  ListingPhoto.remote(this.existing) : file = null;
  final File? file;
  final JsonMap? existing;
}

class ListingDraft {
  ListingDraft({this.original}) {
    final car = original ?? {};
    title = '${car['title'] ?? ''}';
    brandId = '${car['brandId'] ?? listingMap(car['brand'])['id'] ?? ''}';
    final feature = listingMap(car['feature']);
    typeId = '${car['typeId'] ?? listingMap(feature['type'])['id'] ?? ''}';
    year = '${feature['year'] ?? ''}';
    fuel = '${feature['fuel'] ?? 'gasoline'}';
    transmission = '${feature['transmission'] ?? 'automatic'}';
    displayPlan = '${car['displayPlan'] ?? 'daily'}';
    extras = listingMap(feature['extras']);
    vin = '${extras['vin'] ?? ''}';
    amenities.addAll(
      (extras['amenities'] is List ? extras['amenities'] as List : [])
          .whereType<String>()
          .where(listingAmenities.containsKey),
    );
    for (final key in listingSpecLabels.keys) {
      final objectKey = key.substring(0, key.length - 2);
      specIds[key] =
          '${feature[key] ?? listingMap(feature[objectKey])['id'] ?? ''}';
    }
    final existingPhotos = listingList(car['images']);
    existingPhotos.sort(
      (a, b) => (a['sort'] as num? ?? 0).compareTo(b['sort'] as num? ?? 0),
    );
    photos.addAll(existingPhotos.map(ListingPhoto.remote));
    plans.addAll(
      listingList(car['rentalPlan']).map((p) => Map<String, dynamic>.from(p)),
    );
  }
  final JsonMap? original;
  late String title,
      brandId,
      typeId,
      year,
      fuel,
      transmission,
      displayPlan,
      vin;
  late JsonMap extras;
  final specIds = <String, String>{};
  final amenities = <String>{};
  final photos = <ListingPhoto>[];
  final plans = <JsonMap>[];
  // Kept completely separate from the public gallery and never sent on save.
  File? vinPhoto;

  List<String> applyRecognition(
    JsonMap result,
    Map<String, List<JsonMap>> catalogs,
  ) {
    final warnings = <String>[];
    final brand = matchListingCatalog(
      catalogs['brands'] ?? [],
      result['brandName'],
    );
    if (brand != null) {
      brandId = brand;
    } else if (result['brandName'] != null) {
      warnings.add('Choose the brand to confirm the AI result.');
    }
    final type = matchListingCatalog(
      catalogs['types'] ?? [],
      result['vehicleType'],
    );
    if (type != null) typeId = type;
    final name = [
      result['brandName'],
      result['model'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' ');
    if (name.isNotEmpty && (result['model'] != null || title.trim().isEmpty)) {
      title = name;
    }
    final recognizedYear = int.tryParse('${result['year']}');
    if (recognizedYear != null &&
        recognizedYear >= 1900 &&
        recognizedYear <= DateTime.now().year + 2) {
      year = '$recognizedYear';
    }
    if ([
      'gasoline',
      'diesel',
      'electric',
      'hybird',
      'lpg',
      'cng',
    ].contains(result['fuel'])) {
      fuel = result['fuel'];
    }
    if ([
      'automatic',
      'manual',
      'cvt',
      'amt',
      'dct',
      'sp',
    ].contains(result['transmission'])) {
      transmission = result['transmission'];
    }
    if (RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch('${result['vin']}')) {
      vin = result['vin'];
    }
    const aiKeys = {
      'seatId': 'seats',
      'hpId': 'horsePower',
      'speedId': 'speed',
      'odometerId': 'odometer',
      'cylindersId': 'cylinders',
      'engCCId': 'engineCapacity',
    };
    for (final field in aiKeys.entries) {
      var value = result[field.value];
      // The decoder may return engine displacement in cc, while the catalog is liters.
      if (field.key == 'engCCId' && value is num && value > 100) {
        value = value / 1000;
      }
      if (value == null) continue;
      final options = catalogs[field.key] ?? [];
      var id = matchListingCatalog(options, value);
      if (id == null) {
        // Unit-bearing catalog labels ("250 hp") may still be exact numeric matches.
        final target = num.tryParse('$value');
        final matches = options.where((item) {
          final label = catalogText(item).replaceAll(',', '');
          final number = RegExp(
            r'^\s*(\d+(?:\.\d+)?)\s*(?:hp|km/h|km|l)?\s*$',
            caseSensitive: false,
          ).firstMatch(label);
          return target != null &&
              number != null &&
              num.tryParse(number.group(1)!) == target;
        }).toList();
        if (matches.length == 1) id = '${matches.first['id']}';
      }
      if (id != null) {
        specIds[field.key] = id;
      } else {
        warnings.add(
          '${listingSpecLabels[field.key]}: AI suggested $value; choose a matching option.',
        );
      }
    }
    if (result['features'] is List) {
      amenities.addAll(
        (result['features'] as List).whereType<String>().where(
          listingAmenities.containsKey,
        ),
      );
    }
    return warnings;
  }

  String? validate(Map<String, List<JsonMap>> catalogs) {
    if (photos.isEmpty) return 'Add at least one car photo.';
    if (photos.length > 5) return 'Choose up to five car photos.';
    if (vinPhoto != null && photos.any((p) => p.file?.path == vinPhoto!.path)) {
      return 'Remove the VIN photo from the public car photos.';
    }
    if (title.trim().length < 3 || title.trim().length > 100) {
      return 'Use a car name between 3 and 100 characters.';
    }
    if (!(catalogs['brands'] ?? []).any((b) => b['id'] == brandId)) {
      return 'Choose the car brand.';
    }
    final y = int.tryParse(year);
    if (year.isNotEmpty &&
        (y == null || y < 1900 || y > DateTime.now().year + 2)) {
      return 'Enter a valid model year.';
    }
    if (vin.trim().isNotEmpty &&
        !RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin.trim().toUpperCase())) {
      return 'The optional VIN must contain 17 valid letters and numbers.';
    }
    if (plans.isEmpty) return 'Add at least one rental plan.';
    // The existing create/update API accepts up to three simultaneous plans.
    if (plans.length > 3) return 'Choose up to three rental plans.';
    final periods = <String>{};
    for (final plan in plans) {
      final period = '${plan['periodType']}';
      if (!periods.add(period)) return 'Choose each rental period only once.';
      if (!(catalogs['plans'] ?? []).any((p) => p['periodType'] == period)) {
        return 'A rental plan is no longer available. Choose another period.';
      }
      final price = num.tryParse('${plan['price']}'.replaceAll(',', '').trim());
      if (price == null || !price.isFinite || price <= 0) {
        return 'Enter a price greater than zero for every plan.';
      }
    }
    if (!periods.contains(displayPlan)) {
      return 'Choose an active rental plan as the display price.';
    }
    return null;
  }

  JsonMap fields(
    Map<String, List<JsonMap>> catalogs, {
    required bool personal,
    String? companyId,
  }) {
    final feature = <String, dynamic>{
      'year': year.isEmpty ? null : int.parse(year),
      'fuel': fuel,
      'transmission': transmission,
      if (typeId.isNotEmpty) 'carTypeId': typeId,
      for (final spec in specIds.entries)
        if (spec.value.isNotEmpty) spec.key: spec.value,
      'extras': {
        ...extras,
        'amenities': amenities.toList(),
        if (vin.trim().isNotEmpty)
          'vin': vin.trim().toUpperCase()
        else
          'vin': null,
      },
    };
    final newPlans = <JsonMap>[];
    final oldPlans = listingList(original?['rentalPlan']);
    final deleted = <JsonMap>[];
    for (final old in oldPlans) {
      if (!plans.any((p) => p['id'] == old['id'])) {
        deleted.add({'id': old['id']});
      }
    }
    for (final p in plans) {
      final catalog = (catalogs['plans'] ?? []).firstWhere(
        (c) => c['periodType'] == p['periodType'],
      );
      final price = num.parse('${p['price']}'.replaceAll(',', '').trim());
      final old = oldPlans.where((x) => x['id'] == p['id']).firstOrNull;
      if (old != null &&
          num.tryParse('${old['price']}') == price &&
          old['currency'] == p['currency'] &&
          old['periodType'] == p['periodType']) {
        continue;
      }
      if (old != null) deleted.add({'id': old['id']});
      newPlans.add({
        'planId': catalog['id'],
        'periodType': p['periodType'],
        'price': price,
        'currency': p['currency'] ?? 'usd',
        'available': p['available'] ?? true,
        'min': p['min'],
        'max': p['max'],
      });
    }
    final removedPhotos = listingList(
      original?['images'],
    ).where((old) => !photos.any((p) => p.existing?['id'] == old['id']));
    return {
      if (original != null) 'id': original!['id'],
      if (original == null && companyId != null) 'companyId': companyId,
      'title': title.trim(),
      'brandId': brandId,
      if (typeId.isNotEmpty) 'typeId': typeId,
      'displayPlan': displayPlan,
      'feature': jsonEncode(feature),
      if (original == null) 'available': (!personal).toString(),
      if (newPlans.isNotEmpty) 'rentalPlan': jsonEncode(newPlans),
      if (deleted.isNotEmpty) 'deletedRentalPlans': jsonEncode(deleted),
      if (removedPhotos.isNotEmpty)
        'deletedImages': jsonEncode(
          removedPhotos
              .map((p) => {'id': p['id'], 'image': p['image']})
              .toList(),
        ),
    };
  }
}

class ListingService {
  ListingService(this.api);
  final ApiService api;
  Future<Profile> refreshProfile() async => ProfileMapper.fromMap(
    listingMap(await api.post<dynamic>('/auth/refresh', data: {})),
  );
  Future<List<JsonMap>> cars(Profile profile, {String? cursor}) async {
    // Never send an unscoped getCars request: old servers treat no companyId as all cars.
    if (profile.company == null) return [];
    return listingList(
      await api.post<dynamic>(
        '/company/getCars',
        data: {'companyId': profile.company!.id, 'cursor': cursor},
      ),
    );
  }

  Future<Map<String, List<JsonMap>>> catalogs() async {
    final entries = await Future.wait(
      listingCatalogPaths.entries.map(
        (entry) async => MapEntry(
          entry.key,
          listingList(
            await api.post<dynamic>('/company/${entry.value}', data: {}),
          ),
        ),
      ),
    );
    final result = Map<String, List<JsonMap>>.fromEntries(entries);
    if ((result['brands'] ?? []).isEmpty || (result['plans'] ?? []).isEmpty) {
      throw const FormatException(
        'Car brands or rental plans are unavailable. Please reload the form or contact Carva support.',
      );
    }
    return result;
  }

  Future<MultipartFile> _image(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      'heic' => 'heic',
      'heif' => 'heif',
      _ => 'jpeg',
    };
    return MultipartFile.fromFile(
      file.path,
      filename: file.uri.pathSegments.last,
      contentType: MediaType('image', mime),
    );
  }

  Future<JsonMap> recognize(File image, List<JsonMap> brands) async {
    if (await image.length() > 10 * 1024 * 1024) {
      throw const FormatException('Use an image smaller than 10 MB.');
    }
    final form = FormData.fromMap({
      'image': await _image(image),
      'brandCatalog': jsonEncode(
        brands.map((b) => b['en']).whereType<String>().toList(),
      ),
    });
    return listingMap(
      await api.post<dynamic>(
        '/company/car/recognize',
        data: form,
        options: Options(
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 2),
        ),
      ),
    );
  }

  Future<String?> save(
    ListingDraft draft,
    Map<String, List<JsonMap>> catalogs,
    Profile profile,
  ) async {
    if (!canManageListings(profile)) {
      throw const FormatException(
        'Identity verification is required before posting a car.',
      );
    }
    final error = draft.validate(catalogs);
    if (error != null) throw FormatException(error);
    final form = FormData.fromMap(
      draft.fields(
        catalogs,
        personal: personalOwner(profile),
        companyId: profile.company?.id,
      ),
    );
    for (final photo in draft.photos) {
      if (photo.file != null) {
        form.files.add(MapEntry('images', await _image(photo.file!)));
      }
    }
    await api.post<dynamic>(
      draft.original == null ? '/company/car/new' : '/company/car/update',
      data: form,
      options: Options(
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    if (draft.original == null) {
      return null; // New uploads already follow gallery order.
    }
    try {
      final originalIds = listingList(
        draft.original!['images'],
      ).map((p) => p['id']).toSet();
      JsonMap? updated;
      String? cursor;
      do {
        final page = await cars(profile, cursor: cursor);
        updated = page
            .where((c) => c['id'] == draft.original!['id'])
            .firstOrNull;
        if (updated != null || page.length < 15) break;
        final next = '${page.last['id']}';
        if (next == cursor) break;
        cursor = next;
      } while (true);
      if (updated == null) {
        throw const FormatException('Unable to refresh photos.');
      }
      final uploaded =
          listingList(
            updated['images'],
          ).where((p) => !originalIds.contains(p['id'])).toList()..sort(
            (a, b) =>
                (a['sort'] as num? ?? 0).compareTo(b['sort'] as num? ?? 0),
          );
      var next = 0;
      final ordered = <JsonMap>[];
      for (var i = 0; i < draft.photos.length; i++) {
        final photo = draft.photos[i];
        final id = photo.existing?['id'] ?? uploaded[next++]['id'];
        ordered.add({'id': id, 'carId': draft.original!['id'], 'sort': i});
      }
      await api.post<dynamic>('/company/car/sort', data: ordered);
      return null;
    } catch (_) {
      return 'Your changes were saved, but photo ordering could not be updated. Open the listing and reorder the photos again.';
    }
  }
}

String listingError(Object error) {
  if (error is FormatException) return error.message;
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Please sign in again to continue.';
    if (error.statusCode == 403) {
      return 'Posting access is unavailable. Check your verification or company account status.';
    }
    if (error.statusCode == 402) {
      return 'AI recognition is temporarily unavailable. You can fill in the details manually.';
    }
    var message = error.message;
    try {
      final data = jsonDecode(message);
      message = '${data['message'] ?? data['error'] ?? message}';
    } catch (_) {}
    if (message.isNotEmpty &&
        message.length < 200 &&
        !message.contains('<') &&
        !message.contains('stack')) {
      return message;
    }
  }
  return 'Could not complete the request. Please check your connection and try again.';
}
