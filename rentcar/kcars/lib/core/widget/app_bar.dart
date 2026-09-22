import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/back_button.dart';
import 'package:kcars/core/widget/custom_alert.dart';
import 'package:kcars/core/widget/icon_loader.dart';
import 'package:kcars/features/user/presentation/view/supports_view.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';

class HomeAppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    this.hasBackButton = false,
    this.backgroundColor,
    this.widget,
  });
  final bool hasBackButton;
  final Color? backgroundColor;
  final Widget? widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (widget != null) {
      // The public home uses a two-row header.  Keeping the controls in a
      // second row prevents the city, advertise and search actions from
      // being squeezed out of the old single-row AppBar title.
      return AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 112,
        titleSpacing: 0,
        title: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Row(
                    children: [
                      Image.asset(AppIcons.carva, width: 22.w, height: 10.w),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          textStyle: context.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: context.primaryContainer,
                          foregroundColor: context.onSurface,
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                        ),
                        onPressed: () => showCustomBottomSheet(
                          context,
                          SupportsView(),
                          useRootNavigator: true,
                        ),
                        child: Text(LocaleKeys.labels_rentCar.tr()),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 48, child: widget),
            ],
          ),
        ),
      );
    }

    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: false,
      leading: hasBackButton
          ? CustomBackButton(appBarHasBackground: backgroundColor != null)
          : null,
      title: SafeArea(
        child: GestureDetector(
          child: Row(
            children: [
              Image.asset(AppIcons.carva, width: 24.w, height: 24.w),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: context.label.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: context.primaryContainer,
                  foregroundColor: context.onSurface,
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                ),
                onPressed: () {
                  showCustomBottomSheet(
                    context,
                    SupportsView(),
                    useRootNavigator: true,
                  );
                },
                child: Text(LocaleKeys.labels_rentCar.tr()),
              ),
              ?widget,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(widget == null ? kToolbarHeight : 112);
}

class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.hasBadge = false,
    this.hasBackground = false,
    this.iconColor,
    this.color,
  });
  final String icon;
  final VoidCallback? onTap;
  final bool hasBadge;
  final bool hasBackground;
  final Color? iconColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: hasBackground
            ? context.surface
            : color ?? context.surfaceContainerLowest,
      ),
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: hasBadge,
        child: IconLoadaer(icon, color: iconColor),
      ),
    );
  }
}
