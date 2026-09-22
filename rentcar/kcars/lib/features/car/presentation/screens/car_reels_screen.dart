import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/services/info.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/app_settings/data/model/sliders.dart';
import 'package:kcars/features/app_settings/presentation/riverpod/sliders.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/presentation/riverpod/reels_cars.dart';
import 'package:kcars/features/car/presentation/widget/ad_interleave.dart';
import 'package:kcars/features/car/presentation/widget/favroite_button.dart';
import 'package:kcars/features/car/presentation/widget/share_car.dart';
import 'package:kcars/features/car/presentation/widget/slider_tap.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';
import 'package:collection/collection.dart';

/// Full-screen, one-car-per-page vertical feed — TikTok/Reels-style
/// discovery layer on top of the same Featured rotation the Home strip
/// uses. Opened from [CarReelsPreviewStrip]; each card links back out to
/// the real car-details page and the company profile, so this is purely
/// a presentation layer, not a second source of truth for car data.
@RoutePage()
class CarReelsScreen extends HookConsumerWidget {
  const CarReelsScreen({super.key, this.initialCarId});

  final String? initialCarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(reelsCarsProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final ads = ref.watch(allSlidersProvider).asData?.value ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: cars.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Text(
                LocaleKeys.empty_cars.tr(),
                style: context.body.copyWith(color: Colors.white),
              ),
            );
          }
          final slots = interleaveAds(data, ads, every: carsBeforeAd);
          final initialIndex = initialCarId == null
              ? 0
              : slots
                    .indexWhere((s) => s.item?.carId == initialCarId)
                    .clamp(0, slots.length - 1);
          return _ReelsPageView(
            slots: slots,
            initialIndex: initialIndex,
            isLoggedIn: isLoggedIn,
          );
        },
        error: (error, trace) => Center(
          child: Text(
            error.toString(),
            style: context.body.copyWith(color: Colors.white),
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}

class _ReelsPageView extends HookWidget {
  const _ReelsPageView({
    required this.slots,
    required this.initialIndex,
    required this.isLoggedIn,
  });

  final List<AdSlot<Car>> slots;
  final int initialIndex;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final controller = usePageController(initialPage: initialIndex);

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return slot.isAd
                ? _ReelAdPage(ad: slot.ad!)
                : _ReelCard(car: slot.item!, isLoggedIn: isLoggedIn);
          },
        ),
        PositionedDirectional(
          top: 12.w,
          start: 4.w,
          child: SafeArea(
            bottom: false,
            child: _GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.router.maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelCard extends HookWidget {
  const _ReelCard({required this.car, required this.isLoggedIn});

  final Car car;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final images = car.images ?? [];
    final imageIndex = useState(0);
    // Bumped on every manual change so the auto-advance timer restarts
    // and doesn't fire immediately after the reader just swiped.
    final cycleTick = useState(0);

    useEffect(() {
      if (images.length <= 1) return null;
      final timer = Timer.periodic(const Duration(seconds: 4), (_) {
        imageIndex.value = (imageIndex.value + 1) % images.length;
      });
      return timer.cancel;
    }, [images.length, cycleTick.value]);

    void step(int delta) {
      if (images.length <= 1) return;
      imageIndex.value =
          (imageIndex.value + delta + images.length) % images.length;
      cycleTick.value++;
    }

    final rentPlan = car.rentalPlan?.firstWhereOrNull(
      (plan) => plan.periodType == car.displayPlan,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // An explicit horizontal-drag recogniser rather than a nested
        // PageView: inside the vertical reel PageView the inner one never
        // won the gesture, so photos could only ever advance on their own.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v == 0) return;
            // Swiping left (negative velocity) reveals the next photo.
            step(v < 0 ? 1 : -1);
          },
          child: Hero(
            tag: 'reel-${car.id}',
            child: SizedBox.expand(
              // Deliberately no transition: photos cut over instantly,
              // like flicking through a phone's gallery.
              child: images.isEmpty
                  ? Container(color: context.photoPlaceholder)
                  : _ReelImage(
                      key: ValueKey(imageIndex.value),
                      url: "${Info.imageUrl}/${images[imageIndex.value].image}",
                    ),
            ),
          ),
        ),
        // Must not take hits: a plain DecoratedBox reports itself as hit
        // across its whole rect, which swallowed every horizontal drag
        // before it could reach the photo PageView underneath.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xE6000000), Colors.transparent],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          PositionedDirectional(
            top: 12.w,
            start: 4.w,
            end: 4.w,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: List.generate(images.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.symmetric(horizontal: 0.6.w),
                      decoration: BoxDecoration(
                        color: i == imageIndex.value
                            ? Colors.white
                            : Colors.white.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        PositionedDirectional(
          end: 3.w,
          bottom: 30.w,
          child: Column(
            children: [
              FavoriteButton(
                isFavorited: car.isFavorite == true,
                car: car,
                brandId: car.brand?.id,
                isLoggedIn: isLoggedIn,
                color: Colors.white,
              ),
              Gap(4.w),
              _GlassIconButton(
                icon: Icons.share_rounded,
                onTap: () => shareCar(car),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          start: 5.w,
          end: 22.w,
          bottom: 6.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (car.company != null)
                GestureDetector(
                  onTap: () => context.router.push(
                    CompanyDetailsRoute(companyId: car.company!.id),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: ImageHolder(
                          image: car.company?.image,
                          type: ImageType.company,
                          width: 8.w,
                          height: 8.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Gap(2.w),
                      Flexible(
                        child: Text(
                          car.company!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.bodySemiBild.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Gap(2.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: .7),
                        size: 5.w,
                      ),
                    ],
                  ),
                ),
              Gap(1.8.w),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.router.push(
                  CarDetailsRoute(carId: car.carId ?? ""),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 1.2.w),
                  child: Text(
                    car.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.title2Bold.copyWith(color: Colors.white),
                  ),
                ),
              ),
              Gap(0.3.w),
              Text(
                "${car.feature?.year ?? '–'} · ${car.feature?.transmission?.transmissionType() ?? ''}",
                style: context.label.copyWith(
                  color: Colors.white.withValues(alpha: .8),
                ),
              ),
              if (rentPlan != null) ...[
                Gap(2.w),
                Text.rich(
                  TextSpan(
                    text:
                        "${rentPlan.price.forMatNumber()} ${rentPlan.currency?.getCurrency() ?? ''}",
                    style: context.mono.copyWith(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: " / ${rentPlan.periodType.periodPerType()}",
                        style: context.label.copyWith(
                          color: Colors.white.withValues(alpha: .8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A sponsored slot dropped into the reel feed every few cars — a static
/// full-screen page (no auto-cycling image, no favorite/share rail) so it
/// reads as a deliberate ad break rather than another car.
class _ReelAdPage extends ConsumerWidget {
  const _ReelAdPage({required this.ad});

  final Sliders ad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => handleSliderTap(context, ref, ad),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ReelImage(url: "${Info.imageUrl}/${ad.image}"),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Colors.transparent],
                  stops: [0.0, 0.4],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 5.w,
            end: 5.w,
            bottom: 10.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.5.w,
                    vertical: 0.8.w,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99111111),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    LocaleKeys.labels_ad.tr(),
                    style: context.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Gap(3.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LocaleKeys.labels_learnMore.tr(),
                      style: context.title2Bold.copyWith(color: Colors.white),
                    ),
                    Gap(1.5.w),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 4.w,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the photo at its own real proportions (BoxFit.contain) instead of
/// cropping it to fill the screen — most car photos are landscape shots
/// that would lose the front/back of the car under a naive BoxFit.cover.
/// A blurred, darkened copy of the same photo fills the letterbox space
/// behind it so there's no stark black bars.
class _ReelImage extends StatelessWidget {
  const _ReelImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            color: const Color(0x99000000),
            colorBlendMode: BlendMode.darken,
            placeholder: (context, url) =>
                Container(color: context.photoPlaceholder),
            errorWidget: (context, url, error) =>
                Container(color: context.photoPlaceholder),
          ),
        ),
        Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => Container(
              color: context.photoPlaceholder,
              child: const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: const Color(0x73111111),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x2EFFFFFF)),
        ),
        child: Icon(icon, color: Colors.white, size: 5.w),
      ),
    );
  }
}
