import 'package:auto_route/auto_route.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:collection/collection.dart';

/// One large car shown at a time, auto-advancing to the next — the
/// Featured section's hero treatment, as opposed to the smaller
/// horizontal-scroll cards used elsewhere (Nearby, Recently Viewed).
class FeaturedHeroCarousel extends HookWidget {
  const FeaturedHeroCarousel({
    super.key,
    required this.cars,
    required this.isLoggedIn,
  });

  final List<Car> cars;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final activeIndex = useState(0);

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: cars.length,
          options: CarouselOptions(
            height:
                78.w +
                (MediaQuery.textScalerOf(context).scale(100) - 100).clamp(
                  0,
                  140,
                ),
            viewportFraction: 1,
            autoPlay: cars.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 700),
            onPageChanged: (index, reason) => activeIndex.value = index,
          ),
          itemBuilder: (context, index, realIndex) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: _FeaturedHeroCard(
                car: cars[index],
                isLoggedIn: isLoggedIn,
              ),
            );
          },
        ),
        if (cars.length > 1) ...[
          Gap(3.w),
          AnimatedSmoothIndicator(
            activeIndex: activeIndex.value,
            count: cars.length,
            effect: ExpandingDotsEffect(
              dotHeight: 1.8.w,
              dotWidth: 1.8.w,
              activeDotColor: const Color(0xFFB5121B),
              dotColor: context.hairline,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedHeroCard extends StatelessWidget {
  const _FeaturedHeroCard({required this.car, required this.isLoggedIn});

  final Car car;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final rentPlan = car.rentalPlan?.firstWhereOrNull(
      (plan) => plan.periodType == car.displayPlan,
    );

    return GestureDetector(
      onTap: () =>
          context.router.push(CarDetailsRoute(carId: car.carId ?? car.id)),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: context.photoPlaceholder,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0x24171214),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageHolder(
              image: car.images?.firstOrNull?.image,
              type: ImageType.car,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.38, 0.72, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: .92),
                    Colors.black.withValues(alpha: .70),
                    Colors.black.withValues(alpha: .12),
                    Colors.black.withValues(alpha: .0),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 4.w,
              start: 4.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFB5121B),
                  borderRadius: BorderRadius.circular(100.w),
                ),
                child: Text(
                  LocaleKeys.labels_featured.tr().toUpperCase(),
                  style: context.mono.copyWith(
                    fontSize: 9.sp,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 5.w,
              start: 5.w,
              end: 5.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    car.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleBold.copyWith(
                      fontSize: 16.sp,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                  Gap(2.5.w),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (car.feature?.year != null)
                        _HeroDetail(
                          icon: Icons.calendar_today_rounded,
                          text: '${car.feature!.year}',
                        ),
                      if (car.feature?.transmission != null)
                        _HeroDetail(
                          icon: Icons.settings_outlined,
                          text: car.feature!.transmission!.transmissionType(),
                        ),
                    ],
                  ),
                  if (rentPlan != null) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: rentPlan.price.forMatNumber(),
                            children: [
                              TextSpan(
                                text:
                                    ' ${rentPlan.currency?.getCurrency() ?? ''}',
                                style: context.label.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          style: context.mono.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          rentPlan.periodType.periodPerType(),
                          style: context.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFE5E9F0),
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
    );
  }
}

class _HeroDetail extends StatelessWidget {
  const _HeroDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFCED8E9)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: context.label.copyWith(
              fontSize: 14,
              height: 1.35,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
