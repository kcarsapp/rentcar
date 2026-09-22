import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/data/model/post_location.dart';
import 'package:kcars/features/car/presentation/widget/brand_mark.dart';
import 'package:kcars/features/car/presentation/widget/car_context_preview.dart';
import 'package:sizer/sizer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:collection/collection.dart';

class CarWidget extends StatefulWidget {
  const CarWidget({
    super.key,
    this.cars,
    this.isSkeleton = false,
    this.param,
    this.isLoggedIn = false,
  });

  final List<Car>? cars;
  final bool isSkeleton;
  final PostLocation? param;
  final bool isLoggedIn;

  @override
  State<CarWidget> createState() => _CarWidgetState();
}

class _CarWidgetState extends State<CarWidget> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoSlideTimer;
  Timer? _resumeTimer;
  bool _userIsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoSlide();
  }

  @override
  void didUpdateWidget(covariant CarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cars != widget.cars ||
        oldWidget.isSkeleton != widget.isSkeleton) {
      _scheduleAutoSlide();
    }
  }

  void _scheduleAutoSlide() {
    _autoSlideTimer?.cancel();
    if (widget.isSkeleton || (widget.cars?.length ?? 0) < 2) return;
    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _advanceCards(),
    );
  }

  void _pauseForUser() {
    _userIsScrolling = true;
    _resumeTimer?.cancel();
  }

  void _resumeAfterUser() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _userIsScrolling = false;
    });
  }

  void _advanceCards() {
    if (!mounted || _userIsScrolling || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    // Two cards are visible in the rail, so advance by a full two-card page.
    final cardExtent = 47.6.w * 2;
    final nextOffset = position.pixels + cardExtent;
    final target = position.pixels >= position.maxScrollExtent - 2
        ? 0.0
        : nextOffset.clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.isSkeleton ? 3 : widget.cars?.length ?? 0;
    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _pauseForUser();
          } else if (notification is UserScrollNotification) {
            if (notification.direction == ScrollDirection.idle) {
              _resumeAfterUser();
            } else {
              _pauseForUser();
            }
          }
          return false;
        },
        child: Skeletonizer(
          enabled: widget.isSkeleton,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 8),
            itemCount: itemCount,
            itemBuilder: (context, index) =>
                _RailCard(car: widget.isSkeleton ? null : widget.cars![index]),
          ),
        ),
      ),
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({this.car});
  final Car? car;

  @override
  Widget build(BuildContext context) {
    final plan = car?.rentalPlan?.firstWhereOrNull(
      (p) => p.periodType == car!.displayPlan,
    );
    final specs = [
      if (car?.feature?.year != null) '${car!.feature!.year}',
      if (car?.feature?.transmission != null)
        car!.feature!.transmission!.transmissionType(),
    ];
    return Container(
      margin: EdgeInsets.symmetric(horizontal: .8.w),
      width: 46.w,
      child: SpringPressable(
        semanticsLabel: car?.title,
        onTap: car == null
            ? null
            : () => context.router.push(
                CarDetailsRoute(carId: car!.carId ?? car!.id),
              ),
        onLongPress: car == null
            ? null
            : () => showCarContextPreview(context, car!),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 23.w,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: carImageHeroTag(
                          car?.carId ?? car?.id ?? 'skeleton',
                        ),
                        child: ImageHolder(
                          image: car?.images?.firstOrNull?.image,
                          type: ImageType.car,
                          fit: BoxFit.cover,
                          width: 46.w,
                          height: 23.w,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      if (car?.brand != null)
                        PositionedDirectional(
                          top: 10,
                          end: 10,
                          child: BrandMark(
                            brand: car!.brand,
                            size: 7,
                            dark: true,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car?.title ?? 'Car',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        specs.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      if (plan != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${plan.price.forMatNumber()} ${plan.currency?.getCurrency() ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB5121B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.periodType.periodPerType(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF667085),
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
    );
  }
}
