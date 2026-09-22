import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/buttons.dart';
import 'package:kcars/core/widget/custom_alert.dart';
import 'package:kcars/core/widget/icon_loader.dart';
import 'package:kcars/features/car/data/model/city.dart';
import 'package:kcars/features/car/presentation/riverpod/filters_data.dart';
import 'package:kcars/features/car/presentation/riverpod/home_city_filter.dart';
import 'package:kcars/features/user/presentation/view/supports_view.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';

/// Replaces the old logo bar: a city narrowing control on one side, an
/// "advertise with us" shortcut and the search pill on the other.
///
/// The city control narrows the Home feed in place (see
/// [homeCityFilterProvider]) — it is NOT the search screen's city filter
/// and never opens another screen.
class HomeTopControls extends HookConsumerWidget {
  const HomeTopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(filtersDataProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Expanded(
            child: dataAsync.when(
              data: (data) => _CitySelect(cities: data.cities ?? []),
              // Keep the city affordance visible while the filter endpoint
              // is loading or temporarily unavailable.
              loading: () => const _CitySelect(cities: []),
              error: (error, trace) => const _CitySelect(cities: []),
            ),
          ),
          Gap(2.w),
          const _AdvertiseButton(),
          Gap(2.w),
          GestureDetector(
            onTap: () => context.router.push(FilterRoute()),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconLoadaer(AppIcons.search, color: Colors.white, width: 4.w),
                  Gap(1.5.w),
                  Text(
                    LocaleKeys.buttons_search.tr(),
                    style: context.label.copyWith(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tiny "advertise with Carva" entry — opens the same contact-channels
/// dialog the old SponsorCard used, so no new contact plumbing.
class _AdvertiseButton extends StatelessWidget {
  const _AdvertiseButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showCustomAlert(
          context,
          title: 'Advertise with Carva',
          child: const SupportsView(),
          primaryButtonText: LocaleKeys.buttons_close.tr(),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.primaryContainer,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_rounded, size: 4.5.w, color: context.primary),
            Gap(1.w),
            Text(
              'Advertise',
              style: context.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitySelect extends HookConsumerWidget {
  const _CitySelect({required this.cities});
  final List<City> cities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeCityFilterProvider);
    final locale = context.locale.toLanguageTag();

    String label;
    if (selected.isEmpty) {
      label = 'All cities';
    } else if (selected.length == 1) {
      label = cities
          .where((c) => selected.contains(cityKey(c.en)))
          .map((c) => c.getTitle(locale))
          .join();
      // Keep the control readable while the filter endpoint is refreshing.
      if (label.isEmpty) label = selected.first;
    } else {
      label = '${selected.length} ${LocaleKeys.labels_city.tr()}';
    }

    return GestureDetector(
      // Do not disable this control while filtersData is loading.  A failed
      // first request used to leave a visible, but permanently inert, button.
      onTap: () => _openCityPicker(context, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 5.w, color: context.primary),
          Gap(1.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.label.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 5.w,
            color: context.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Future<void> _openCityPicker(BuildContext context, WidgetRef ref) async {
    var availableCities = cities;

    if (availableCities.isEmpty) {
      try {
        final fresh = await ref.refresh(filtersDataProvider.future);
        availableCities = fresh.cities ?? <City>[];
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cities are unavailable. Try again.')),
        );
        return;
      }
    }

    if (!context.mounted) return;
    if (availableCities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cities are available yet.')),
      );
      return;
    }

    _showCityPicker(context, ref, availableCities);
  }

  void _showCityPicker(
    BuildContext context,
    WidgetRef ref,
    List<City> availableCities,
  ) {
    final current = ref.read(homeCityFilterProvider);
    final temp = Set<String>.of(current);
    final locale = context.locale.toLanguageTag();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                ).copyWith(bottom: 4.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose cities',
                      textAlign: TextAlign.center,
                      style: context.label2SemiBold,
                    ),
                    Gap(3.w),
                    CheckboxListTile(
                      value: temp.isEmpty,
                      onChanged: (_) => setSheetState(temp.clear),
                      title: Text('All cities', style: context.label),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: context.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    Divider(color: context.hairline, height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: availableCities
                            .map(
                              (city) => CheckboxListTile(
                                value: temp.contains(cityKey(city.en)),
                                onChanged: (checked) => setSheetState(() {
                                  if (checked == true) {
                                    temp.add(cityKey(city.en));
                                  } else {
                                    temp.remove(cityKey(city.en));
                                  }
                                }),
                                title: Text(
                                  city.getTitle(locale),
                                  style: context.label,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: context.primary,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Gap(4.w),
                    PrimaryButton(
                      height: 12.w,
                      borderRadius: BorderRadius.circular(100),
                      text: 'Apply',
                      onPress: () {
                        // Selecting every city = no narrowing at all.
                        final all = availableCities
                            .map((c) => cityKey(c.en))
                            .toSet();
                        ref
                            .read(homeCityFilterProvider.notifier)
                            .setCities(
                              temp.length >= all.length ? <String>{} : temp,
                            );
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
