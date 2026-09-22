import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/app_settings/presentation/riverpod/sliders.dart';
import 'package:kcars/features/car/presentation/riverpod/reels_cars.dart';
import 'package:kcars/features/car/presentation/widget/ad_banner_card.dart';
import 'package:kcars/features/car/presentation/widget/ad_interleave.dart';
import 'package:sizer/sizer.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Entry point into the Reels feed — a manually-scrollable strip of
/// portrait thumbnails (same view-tier rotation the full-screen Reels
/// feed uses) that opens CarReelsScreen at the tapped car.
class CarReelsPreview extends HookConsumerWidget {
  const CarReelsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(reelsCarsProvider);
    final ads = ref.watch(allSlidersProvider).asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap(2.w),
        SizedBox(
          height: 54.w,
          child: cars.when(
            data: (data) {
              if (data.isEmpty) return const SizedBox.shrink();
              final preview = data.take(10).toList();
              final slots = interleaveAds(preview, ads, every: carsBeforeAd);
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  if (slot.isAd) {
                    return AdBannerCard(
                      ad: slot.ad!,
                      width: 34.w,
                      height: 54.w,
                      margin: EdgeInsets.symmetric(horizontal: 1.w),
                    );
                  }
                  final car = slot.item!;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1.w),
                    child: GestureDetector(
                      onTap: () => context.router.push(
                        CarReelsRoute(initialCarId: car.carId),
                      ),
                      child: Hero(
                        tag: 'reel-${car.id}',
                        child: Container(
                          width: 34.w,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.hairline),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageHolder(
                                image: car.images?.first.image,
                                type: ImageType.car,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.zero,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xB3000000),
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.6],
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                bottom: 2.5.w,
                                start: 2.5.w,
                                end: 2.5.w,
                                child: Text(
                                  car.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.bodySemiBild.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            error: (error, trace) => const SizedBox.shrink(),
            loading: () => Skeletonizer(
              enabled: true,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                itemCount: 3,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.w),
                  child: Container(
                    width: 34.w,
                    decoration: BoxDecoration(
                      color: context.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
