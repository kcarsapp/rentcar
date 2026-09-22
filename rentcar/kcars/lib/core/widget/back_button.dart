import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/widget/icon_loader.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:sizer/sizer.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    super.key,
    this.isCloss = false,
    this.appBarHasBackground = false,
    this.onPressed,
  });
  final bool isCloss;
  final bool appBarHasBackground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: .7,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: appBarHasBackground
              ? context.surfaceContainerLowest
              : context.surfaceContainerLowest,
          side: BorderSide(
            color: appBarHasBackground
                ? context.surfaceContainerLow
                : context.surfaceContainerLow,
          ),
        ),
        onPressed: onPressed ?? () => _handleBack(context),
        icon: Transform.rotate(
          angle: Directionality.of(context) == TextDirection.rtl ? pi : 0,
          child: IconLoadaer(
            AppIcons.arrow,
            color: context.onSurface,
            width: 10.w,
            height: 10.w,
          ),
        ),
      ),
    );
  }

  /// AutoRoute screens inside a tab have their own router.  In that case
  /// `maybePop` on the local router can report false even though the screen
  /// was pushed by the root router.  Walk up through the routers and finally
  /// the root Navigator so this button behaves consistently everywhere.
  void _handleBack(BuildContext context) {
    AppHaptics.lightTap();

    final localRouter = context.router;
    if (localRouter.canPop()) {
      localRouter.pop();
      return;
    }

    final rootRouter = localRouter.root;
    if (rootRouter.canPop()) {
      rootRouter.pop();
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
