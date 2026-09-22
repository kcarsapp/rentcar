import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/providers/connectivity.dart';
import 'package:kcars/core/providers/shee_controller.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/bottm_bar.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

@RoutePage()
class MainScreen extends StatefulHookConsumerWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkAwareProvider);
    if (network == NetworkStatus.off) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.router.replaceAll([const ConnectivityRoute()]);
      });
    }
    final locale = useMemoized(() => context.locale.languageCode, []);
    final contrller = ref.watch(sheetControllerProvider);
    return AutoTabsScaffold(
      extendBody: true,
      animationDuration: Duration.zero,
      routes: [HomeRoute(), ChatRoute(), AllCompaniesRoute(), SettingsRoute()],
      bottomNavigationBuilder: (context, tab) => SlideTransition(
        position: SheetOffsetDrivenAnimation(
          controller: contrller,
          initialValue: 1,
        ).drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
        child: CustomBottomNavigationBar(
          activeIndex: tab.activeIndex,
          key: ValueKey(locale),
          onTap: (index) {
            tab.setActiveIndex(index);
          },
          tabs: [
            BottmBarModel(
              lable: LocaleKeys.bottomNavigation_car.tr(),
              icon: AppIcons.car,
              activeIcon: AppIcons.carActive,
            ),
            BottmBarModel(
              lable: 'Chat',
              icon: AppIcons.chat,
              activeIcon: AppIcons.chatActive,
            ),
            BottmBarModel(
              lable: LocaleKeys.bottomNavigation_company.tr(),
              icon: AppIcons.company,
              activeIcon: AppIcons.companyFill,
            ),
            BottmBarModel(
              lable: LocaleKeys.bottomNavigation_setting.tr(),
              icon: AppIcons.settings,
              activeIcon: AppIcons.settingsActive,
            ),
          ],
        ),
      ),
    );
  }
}
