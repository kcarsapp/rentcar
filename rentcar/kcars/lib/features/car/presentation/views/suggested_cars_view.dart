import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/presentation/riverpod/suggested_controller.dart';
import 'package:kcars/features/car/presentation/widget/car_widget_view.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';

class SuggestedCarsView extends HookConsumerWidget {
  const SuggestedCarsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(suggestedCarProvider());
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return cars.when(
      // The website omits empty rails completely so the next section moves up.
      data: (data) => data.isEmpty
          ? const SizedBox.shrink()
          : SizedBox(
              height: 66.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      LocaleKeys.labels_suggested.tr(),
                      style: context.label2Bold,
                    ),
                  ),
                  Gap(4.w),
                  CarWidget(cars: data, isLoggedIn: isLoggedIn),
                ],
              ),
            ),
      error: (error, trace) => const SizedBox.shrink(),
      loading: () => SizedBox(
        height: 66.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                LocaleKeys.labels_suggested.tr(),
                style: context.label2Bold,
              ),
            ),
            Gap(4.w),
            CarWidget(isSkeleton: true),
          ],
        ),
      ),
    );
  }
}
