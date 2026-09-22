import 'package:flutter/material.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/car/data/model/brand.dart';
import 'package:sizer/sizer.dart';

/// Small, consistent brand mark used on tabs and car cards.
/// Brand logos come from the same uploaded assets as the web app; the car
/// glyph is a reliable fallback when a brand has no logo yet.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.brand, this.size = 9, this.dark = false});
  final Brand? brand;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final diameter = size.w;
    return Container(
      width: diameter,
      height: diameter,
      padding: EdgeInsets.all(size.w * .12),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(.16) : const Color(0xffffeef0),
        shape: BoxShape.circle,
      ),
      child: brand?.image?.isNotEmpty == true
          ? ImageHolder(
              image: brand!.image,
              type: ImageType.brand,
              width: diameter,
              height: diameter,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(100.w),
            )
          : Icon(
              Icons.directions_car_filled_rounded,
              size: size.w * .5,
              color: dark ? Colors.white : const Color(0xffc51d27),
            ),
    );
  }
}
