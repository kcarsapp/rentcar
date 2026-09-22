import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kcars/core/providers/rotation_session.dart';
import 'package:kcars/core/services/service_location.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/domain/repo/car_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reels_cars.g.dart';

@riverpod
class ReelsCars extends _$ReelsCars {
  late CarRepo _carRepo;
  @override
  FutureOr<List<Car>> build() async {
    _carRepo = sl();

    ref.keepAlive();
    final sessionId = ref.watch(rotationSessionProvider);

    final refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      refreshTimer.cancel();
    });

    final result = await _carRepo.reelsCars(sessionId);

    return result.fold((l) {
      debugPrint("❌ [REELS_CARS_PROVIDER] Error loading reels cars: ${l.message}");
      return <Car>[];
    }, (r) => r);
  }

  void favoriteCar(String id) {
    final newState = state.value
        ?.map(
          (car) =>
              car.id == id ? car.copyWith(isFavorite: !car.isFavorite!) : car,
        )
        .toList();

    state = AsyncData(newState ?? []);
  }
}
