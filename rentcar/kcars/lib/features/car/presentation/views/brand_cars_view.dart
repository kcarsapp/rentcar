import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/utils/auto_scroll_hook.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/custom_tabbar.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/core/widget/loading_emoty_state.dart';
import 'package:kcars/core/widget/section_header.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/data/model/brand.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/presentation/riverpod/brand_cars.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:collection/collection.dart';

class BrandCarsView extends HookConsumerWidget {
  const BrandCarsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(brandCarsProvider);
    final locale = useMemoized(() => context.locale.toLanguageTag(), [
      context.locale,
    ]);

    return SizedBox(
      height: 78.w,
      child: data.when(
        data: (data) {
          return data.isEmpty
              ? EmptyWidget(icon: AppIcons.noCars)
              : CarTabsView(brands: data, locale: locale);
        },
        error: (error, st) => Center(child: Text(error.toString())),
        loading: () => CarTabsView(isSkeleton: true),
      ),
    );
  }
}

class CarTabsView extends HookConsumerWidget {
  final List<Brand>? brands;
  final bool isSkeleton;
  final String locale;
  const CarTabsView({
    super.key,
    this.brands,
    this.isSkeleton = false,
    this.locale = 'en',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final tabs = isSkeleton
        ? ['Toyota', 'Nissan', 'Huuda']
        : brands!.map((b) => b.getTitle(locale)).toList();
    final tabControlelr = useTabController(
      initialLength: tabs.length,
      keys: [
        ValueKey(tabs.length),
        [locale],
      ],
    );

    return Column(
      children: [
        SectionHeader(title: LocaleKeys.labels_brands.tr()),
        Gap(3.w),
        Skeletonizer(
          enabled: isSkeleton,
          child: CustomTabbar(
            key: ValueKey(locale),
            isScrollable: true,
            controller: tabControlelr,
            tabs: isSkeleton
                ? tabs.map((b) => Tab(text: b)).toList()
                : brands!
                      .map((b) => _buildBrandTab(context, b, locale))
                      .toList(),
          ),
        ),
        Gap(2.w),
        Expanded(
          child: TabBarView(
            controller: tabControlelr,
            children: List.generate(tabs.length, (i) {
              final cars = isSkeleton
                  ? List.filled(3, null)
                  : brands?[i].cars ?? [];
              if (cars.isEmpty) {
                return EmptyWidget(
                  icon: AppIcons.noCars,
                  emptyMessage: LocaleKeys.empty_cars.tr(),
                );
              }

              return _BrandTabCarsList(
                cars: cars,
                isSkeleton: isSkeleton,
                brandId: isSkeleton ? null : brands?[i].id,
                isLoggedIn: isLoggedIn,
                locale: locale,
              );
            }),
          ),
        ),
      ],
    );
  }

  Tab _buildBrandTab(BuildContext context, Brand brand, String locale) {
    final logo = brand.image;
    if (logo == null || logo.isEmpty) {
      return Tab(text: brand.getTitle(locale));
    }
    return Tab(
      child: Container(
        width: 18.w,
        height: 9.w,
        padding: EdgeInsets.all(1.5.w),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: context.primary.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ImageHolder(
          image: logo,
          fit: BoxFit.contain,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}

class _BrandTabCarsList extends HookWidget {
  const _BrandTabCarsList({
    required this.cars,
    required this.isSkeleton,
    required this.brandId,
    required this.isLoggedIn,
    required this.locale,
  });
  final List<Car?> cars;
  final bool isSkeleton;
  final String? brandId;
  final bool isLoggedIn;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scrollController = useAutoScrollController(
      enabled: !isSkeleton && cars.length > 1,
      itemExtent: 94.w + 1.4.w,
    );

    return ListView.builder(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      itemCount: cars.length,
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      itemBuilder: (_, index) {
        final car = cars[index];
        return CarCard(
          car: car,
          isSkeleton: isSkeleton,
          brandId: brandId,
          isLoggedIn: isLoggedIn,
          locale: locale,
        );
      },
    );
  }
}

class CarCard extends StatelessWidget {
  final Car? car;
  final bool isSkeleton;
  final String? brandId;
  final bool isLoggedIn;
  final String locale;
  const CarCard({
    super.key,
    this.car,
    this.isSkeleton = false,
    this.brandId,
    this.isLoggedIn = false,
    this.locale = 'en',
  });

  @override
  Widget build(BuildContext context) {
    final rentPlan = car?.rentalPlan?.firstWhereOrNull(
      (plan) => plan.periodType == car!.displayPlan,
    );
    return Skeletonizer(
      enabled: isSkeleton,
      child: GestureDetector(
        onTap: () {
          if (car != null) {
            context.router.push(CarDetailsRoute(carId: car!.carId ?? ""));
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 0.7.w),
          width: 94.w,
          height: 54.w,

          child: Stack(
            children: [
              ImageHolder(
                image: isSkeleton ? null : car!.images?.first.image,
                width: 94.w,
                height: 54.w,
                borderRadius: BorderRadius.circular(20),
                fit: BoxFit.cover,
                isLoading: isSkeleton,
              ),
              if (!isSkeleton)
                Container(
                  width: 94.w,
                  height: 54.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.0, 0.35, 0.6, 1.0],
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.70),
                        Color.fromRGBO(0, 0, 0, 0.50),
                        Color.fromRGBO(0, 0, 0, 0.15),
                        Color.fromRGBO(0, 0, 0, 0.0),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0.w,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: SizedBox(
                    width: 86.w,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.ideographic,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSkeleton ? "Loading..." : car!.title,
                                style: context.title3SemiBold.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Gap(1.5.w),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSkeleton
                                        ? "2020"
                                        : "${car!.feature?.year ?? '–'}",
                                    style: context.mono.copyWith(
                                      fontSize: 10.sp,
                                      color: Colors.white.withValues(
                                        alpha: .78,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 1.5.w,
                                    ),
                                    child: CircleAvatar(
                                      radius: 1.3,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isSkeleton
                                        ? "Automatic"
                                        : car!.feature?.transmission
                                                  ?.transmissionType() ??
                                              '',
                                    style: context.label.copyWith(
                                      fontSize: 10.sp,
                                      color: Colors.white.withValues(
                                        alpha: .78,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isSkeleton || rentPlan != null) ...[
                                Gap(2.w),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isSkeleton
                                          ? "0"
                                          : rentPlan!.price.forMatNumber(),
                                      style: context.mono.copyWith(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    Gap(0.8.w),
                                    Text(
                                      isSkeleton
                                          ? "IQD"
                                          : rentPlan!.currency?.getCurrency() ??
                                                '',
                                      style: context.caption.copyWith(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: .9,
                                        ),
                                      ),
                                    ),
                                    Gap(1.5.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2.w,
                                        vertical: 0.8.w,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .16,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          100.w,
                                        ),
                                      ),
                                      child: Text(
                                        isSkeleton
                                            ? "/ Weekly"
                                            : "/ ${rentPlan!.periodType.periodPerType()}",
                                        style: context.caption.copyWith(
                                          fontSize: 8.5.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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
              if (car?.featuredCars != null)
                PositionedDirectional(
                  top: 4.w,
                  end: 4.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.w,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceTint,
                      borderRadius: BorderRadiusDirectional.circular(100.w),
                    ),
                    child: Text(
                      LocaleKeys.labels_featured.tr(),
                      style: context.caption.copyWith(
                        color: context.surface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
