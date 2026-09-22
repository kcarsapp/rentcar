import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/core/widget/loading_emoty_state.dart';
import 'package:kcars/features/app_settings/presentation/riverpod/sliders.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/application/car_states.dart';
import 'package:kcars/features/car/application/load_more_cars.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/presentation/riverpod/cars.dart';
import 'package:kcars/features/car/presentation/riverpod/featuerd_cars.dart';
import 'package:kcars/features/car/presentation/riverpod/home_city_filter.dart';
import 'package:flutter/rendering.dart';
import 'package:kcars/features/car/presentation/widget/ad_banner_card.dart';
import 'package:kcars/features/car/presentation/widget/ad_interleave.dart';
import 'package:kcars/features/car/presentation/widget/car_context_preview.dart';
import 'package:sizer/sizer.dart';
import 'package:collection/collection.dart';

/// Rearranges cars into pattern: 1 featured, 3 random, 1 featured, 3 random...
/// Featured cars will be repeated cyclically throughout the list.
/// [allFeaturedCars] - List of ALL featured cars (from featuredCarsProvider)
/// [randomCars] - List of non-featured cars to interleave
List<Car> _arrangeCarsInPattern(
  List<Car> allFeaturedCars,
  List<Car> randomCars,
) {
  // If no featured cars, return random cars as-is
  if (allFeaturedCars.isEmpty) {
    return randomCars;
  }

  // If no random cars, return featured cars as-is
  if (randomCars.isEmpty) {
    return allFeaturedCars;
  }

  final arrangedCars = <Car>[];
  int randomIndex = 0;
  int featuredIndex = 0;

  // Create a cycle pattern: 1 featured, 3 random
  // Continue until we've used all random cars
  // Featured cars will cycle/repeat as needed
  while (randomIndex < randomCars.length) {
    // Add 1 featured car (repeat using modulo to cycle through all featured cars)
    arrangedCars.add(allFeaturedCars[featuredIndex % allFeaturedCars.length]);
    featuredIndex++;

    // Add 3 random cars (or remaining if less than 3)
    for (int i = 0; i < 3 && randomIndex < randomCars.length; i++) {
      arrangedCars.add(randomCars[randomIndex]);
      randomIndex++;
    }
  }

  return arrangedCars;
}

class AllCarsView extends HookConsumerWidget {
  const AllCarsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCars = ref.watch(carsProvider);
    final asyncFeaturedCars = ref.watch(featuredCarsProvider);
    final loadMore = ref.watch(loadMoreCarsProvider);
    final isLogged = ref.watch(isLoggedInProvider);
    final ads = ref.watch(allSlidersProvider).asData?.value ?? [];
    final cityFilter = ref.watch(homeCityFilterProvider);

    return asyncCars.when(
      data: (cars) {
        // Get all featured cars (will handle loading/error states)
        // Handle error state explicitly for debugging
        final allFeaturedCars = asyncFeaturedCars.when(
          data: (featured) {
            return featured;
          },
          loading: () {
            return <Car>[];
          },
          error: (error, stack) {
            return <Car>[];
          },
        );

        // Create a set of featured car IDs for efficient lookup
        final featuredCarIds = allFeaturedCars.map((car) => car.id).toSet();

        bool isFeatured(Car car) =>
            car.featuredCars != null || featuredCarIds.contains(car.id);

        // Home's city narrowing applies to THIS list only — the Featured
        // hero and Reels strip above stay untouched. Matching is by
        // English city name (see cityKey) because the cars endpoint
        // returns city names on car.location, not ids.
        //
        // When narrowed, featured cars are filtered too — but through the
        // paginated cars payload, since the featured endpoint strips
        // location entirely, so provider-sourced featured cars can't tell
        // us their city.
        final List<Car> rearrangedCars;
        if (cityFilter.isEmpty) {
          final randomCars = cars.cars
              .where((car) => !isFeatured(car))
              .toList();
          rearrangedCars = _arrangeCarsInPattern(allFeaturedCars, randomCars);
        } else {
          final cityCars = cars.cars.where((car) {
            // Cars without a location of their own belong to their
            // company office's city.
            final en =
                car.location?.city?.en ?? car.company?.location?.city?.en;
            return en != null && cityFilter.contains(cityKey(en));
          }).toList();
          rearrangedCars = _arrangeCarsInPattern(
            cityCars.where(isFeatured).toList(),
            cityCars.where((car) => !isFeatured(car)).toList(),
          );
        }
        final slots = interleaveAds(rearrangedCars, ads, every: carsBeforeAd);
        final rows = <List<AdSlot<Car>>>[];
        for (var index = 0; index < slots.length;) {
          final slot = slots[index];
          if (slot.isAd) {
            rows.add([slot]);
            index++;
            continue;
          }
          final row = <AdSlot<Car>>[slot];
          index++;
          if (index < slots.length && !slots[index].isAd) {
            row.add(slots[index]);
            index++;
          }
          rows.add(row);
        }

        return SliverPadding(
          padding: EdgeInsets.only(bottom: 40.w),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < rows.length) {
                  final row = rows[index];
                  if (row.length == 1 && row.first.isAd) {
                    return AdBannerCard(ad: row.first.ad!);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 33.w + 116,
                          child: CarsWidget(
                            car: row.first.item!,
                            isLoggedIn: isLogged,
                          ),
                        ),
                      ),
                      if (row.length == 2) SizedBox(width: 2.w),
                      if (row.length == 2)
                        Expanded(
                          child: SizedBox(
                            height: 33.w + 116,
                            child: CarsWidget(
                              car: row[1].item!,
                              isLoggedIn: isLogged,
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  );
                }

                // Footer loader if loading more
                if (loadMore is LoadMoreCarsLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircleLoading()),
                  );
                }

                return const SizedBox.shrink();
              },
              childCount:
                  rows.length + (loadMore is LoadMoreCarsLoading ? 1 : 0),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}

bool onScrollNotifications(
  UserScrollNotification notification,
  VoidCallback loadMore,
  bool isLoading,
) {
  // Prevent triggering load more when scrolling up or bouncing at top
  final metrics = notification.metrics;
  final isBottom = metrics.pixels >= metrics.maxScrollExtent - 50;

  if (notification.direction == ScrollDirection.reverse &&
      isBottom &&
      !isLoading) {
    loadMore();
  }

  return false;
}

class CarsWidget extends ConsumerWidget {
  const CarsWidget({super.key, required this.car, this.isLoggedIn = false});
  final Car car;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentPlan = car.rentalPlan?.firstWhereOrNull(
      (plan) => plan.periodType == car.displayPlan,
    );
    final specs = <String>[
      if (car.feature?.year != null) '${car.feature!.year}',
      if (car.feature?.transmission != null)
        car.feature!.transmission!.transmissionType(),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardImageWidth = constraints.maxWidth;
          final cardImageHeight = cardImageWidth / 1.45;
          return SizedBox(
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: DecoratedBox(
              decoration: const BoxDecoration(),
              child: SpringPressable(
                semanticsLabel: car.title,
                onTap: () => context.router.push(
                  CarDetailsRoute(carId: car.carId ?? car.id),
                ),
                onLongPress: () =>
                    showCarContextPreview(context, car, isLoggedIn: isLoggedIn),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: cardImageHeight,
                          child: Hero(
                            tag: carImageHeroTag(car.carId ?? car.id),
                            child: ImageHolder(
                              image: car.images?.firstOrNull?.image,
                              width: cardImageWidth,
                              height: cardImageHeight,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.label2SemiBold.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              if (specs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  specs.join(' · '),
                                  style: context.caption.copyWith(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ],
                              if (rentPlan != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${rentPlan.price.forMatNumber()} ${rentPlan.currency?.getCurrency() ?? ''} · ${rentPlan.periodType.periodPerType()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.label2SemiBold.copyWith(
                                    fontSize: 13,
                                    color: const Color(0xFFB5121B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
