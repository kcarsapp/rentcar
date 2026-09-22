import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/app_settings/presentation/riverpod/detail_car_sponsors.dart';
import 'package:kcars/features/car/presentation/widget/slider_tap.dart';
import 'package:sizer/sizer.dart';

/// Full-width, deliberately short sponsor strip shown above a car's
/// specs. Kept low so it reads as a slim band rather than competing
/// with the car photos — content comes from the admin's
/// "Detail car sponsor" section.
class DetailSponsorStrip extends ConsumerWidget {
  const DetailSponsorStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsors = ref.watch(detailCarSponsorsProvider).asData?.value ?? [];
    if (sponsors.isEmpty) return const SizedBox.shrink();
    final sponsor = sponsors.first;

    return GestureDetector(
      onTap: () => handleSliderTap(context, ref, sponsor),
      child: ImageHolder(
        image: sponsor.image,
        width: double.infinity,
        height: 11.w,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
