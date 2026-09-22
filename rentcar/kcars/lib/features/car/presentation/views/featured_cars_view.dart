import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/widget/loading_emoty_state.dart';
import 'package:kcars/core/widget/section_header.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/presentation/riverpod/featuerd_cars.dart';
import 'package:kcars/features/car/presentation/widget/featured_hero_card.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';
import 'package:skeletonizer/skeletonizer.dart';

class FeaturedCarsView extends HookConsumerWidget {
  const FeaturedCarsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(featuredCarsProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: LocaleKeys.labels_featured.tr()),
        Gap(4.w),
        cars.when(
          data: (data) {
            return data.isEmpty
                ? EmptyWidget(
                    icon: AppIcons.noCars,
                    emptyMessage: LocaleKeys.empty_cars.tr(),
                  )
                : FeaturedHeroCarousel(cars: data, isLoggedIn: isLoggedIn);
          },
          error: (error, trace) => Center(child: Text(error.toString())),
          loading: () => Skeletonizer(
            enabled: true,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Container(
                height: 78.w,
                decoration: BoxDecoration(
                  color: context.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
