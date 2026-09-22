import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/app_settings/data/model/sliders.dart';
import 'package:kcars/features/car/presentation/widget/slider_tap.dart';
import 'package:sizer/sizer.dart';

/// A single static (non-carousel, non-autoplay) sponsored slot dropped
/// into a car list every few items — bigger than the Home carousel's
/// slides so it reads as a deliberate placement, not a stray thumbnail.
class AdBannerCard extends ConsumerWidget {
  const AdBannerCard({
    super.key,
    required this.ad,
    this.width,
    this.height,
    this.margin,
  });

  final Sliders ad;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => handleSliderTap(context, ref, ad),
      child: Container(
        margin: margin ?? EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.w),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            ImageHolder(
              image: ad.image,
              width: width ?? 92.w,
              height: height ?? 40.w,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(18),
            ),
            PositionedDirectional(
              top: 2.w,
              start: 2.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.w),
                decoration: BoxDecoration(
                  color: const Color(0x99111111),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'AD',
                  style: context.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 2.2.w,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
