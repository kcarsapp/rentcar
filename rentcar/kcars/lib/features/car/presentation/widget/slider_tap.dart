import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/utils/launch_links.dart';
import 'package:kcars/features/app_settings/application/app_settigngs_controller.dart';
import 'package:kcars/features/app_settings/data/model/sliders.dart';
import 'package:kcars/features/car/data/model/enums.dart';

/// Shared tap-dispatch for a [Sliders] item — same behavior whether it's
/// shown in the Home carousel or as an inline ad card in a car list.
void handleSliderTap(BuildContext context, WidgetRef ref, Sliders slider) {
  if (slider.type == SlideType.car &&
      slider.carId != null &&
      slider.carId!.isNotEmpty) {
    context.router.push(CarDetailsRoute(carId: slider.car?.carId ?? ""));
  } else if (slider.type == SlideType.company &&
      slider.companyId != null &&
      slider.companyId!.isNotEmpty) {
    context.router.push(CompanyDetailsRoute(companyId: slider.companyId!));
  } else if (slider.type == SlideType.url &&
      slider.url != null &&
      slider.url!.isNotEmpty) {
    openLinks(appLink: slider.url!, webLink: slider.url!);
  }
  if (slider.id != null) {
    ref.read(appSettingsControllerProvider.notifier).slider(slider.id!);
  }
}
