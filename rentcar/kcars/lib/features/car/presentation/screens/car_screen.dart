// ignore_for_file: unused_result

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/utils/permissions.dart';
import 'package:kcars/core/widget/app_bar.dart';
import 'package:kcars/core/widget/section_header.dart';
import 'package:kcars/features/app_settings/presentation/riverpod/sliders.dart';
import 'package:kcars/features/auth/presentation/riverpod/is_logged_in.dart';
import 'package:kcars/features/car/application/car_states.dart';
import 'package:kcars/features/car/application/load_more_cars.dart';
import 'package:kcars/features/car/presentation/riverpod/brand_cars.dart';
import 'package:kcars/features/car/presentation/riverpod/cars.dart';
import 'package:kcars/features/car/presentation/riverpod/featuerd_cars.dart';
import 'package:kcars/features/car/presentation/riverpod/recently_viewed.dart';
import 'package:kcars/features/car/presentation/riverpod/suggested_controller.dart';
import 'package:kcars/features/car/presentation/views/all_cars_view.dart';
import 'package:kcars/features/car/presentation/views/featured_cars_view.dart';
import 'package:kcars/features/car/presentation/widget/home_top_controls.dart';
import 'package:kcars/features/car/presentation/views/filters_data_view.dart';
import 'package:kcars/features/car/presentation/views/recently_views_cars_view.dart';
import 'package:kcars/features/car/presentation/views/sliders_view.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';

@RoutePage()
class CarsScreen extends HookConsumerWidget {
  const CarsScreen({super.key, this.isLogged = true});
  final bool isLogged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogged = ref.watch(isLoggedInProvider);
    final loadMore = ref.watch(loadMoreCarsProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    useMemoized(() => notificaPermission(context), []);

    Future<void> refresh() async {
      await ref.refresh(suggestedCarProvider().future);
      await ref.refresh(brandCarsProvider.future);
      await ref.refresh(allSlidersProvider.future);
      await ref.refresh(featuredCarsProvider.future);
      await ref.refresh(carsProvider.future);
      if (isLogged) {
        await ref.refresh(recentlyViwedCarProvider.future);
      }
    }

    final feed = NotificationListener<UserScrollNotification>(
      onNotification: (notification) => onScrollNotifications(
        notification,
        () => ref.read(carsProvider.notifier).loadMoreCars(),
        loadMore is LoadMoreCarsLoading,
      ),
      child: CustomScrollView(
        physics: isIOS
            ? const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              )
            : null,
        slivers: [
          if (isIOS) CupertinoSliverRefreshControl(onRefresh: refresh),
          SliverToBoxAdapter(child: Gap(2.w)),
          SliverToBoxAdapter(child: FeaturedCarsView()),
          SliverToBoxAdapter(child: Gap(4.w)),
          SliverToBoxAdapter(child: SlidesViwe()),
          SliverToBoxAdapter(child: Gap(4.w)),
          SliverToBoxAdapter(child: RenecentlyViewdCarsView()),
          SliverToBoxAdapter(
            child: SectionHeader(title: LocaleKeys.labels_cars.tr()),
          ),
          SliverToBoxAdapter(child: Gap(3.w)),
          AllCarsView(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: HomeAppBar(widget: HomeTopControls()),
      body: isIOS ? feed : RefreshIndicator(onRefresh: refresh, child: feed),
    );
  }
}

class ContentSheetHandle extends StatelessWidget
    implements PreferredSizeWidget {
  const ContentSheetHandle({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            buildIndicator(),
            Gap(4.w),
            Expanded(child: FiltersDataView()),
          ],
        ),
      ),
    );
  }

  Widget buildIndicator() {
    return Container(
      height: 6,
      width: 40,
      decoration: const ShapeDecoration(
        color: Colors.black12,
        shape: StadiumBorder(),
      ),
    );
  }
}
