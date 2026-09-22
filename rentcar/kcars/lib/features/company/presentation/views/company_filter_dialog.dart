import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/buttons.dart';
import 'package:kcars/features/car/presentation/views/brands_content.dart';
import 'package:kcars/features/company/presentation/riverpod/cities.dart';
import 'package:kcars/features/company/presentation/riverpod/towns.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class CompanyFilterDialog extends HookConsumerWidget {
  const CompanyFilterDialog({
    super.key,
    this.selectedCityId,
    this.selectedTownId,
    required this.onApply,
  });

  final String? selectedCityId;
  final String? selectedTownId;
  final Function(String? cityId, String? townId) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = useMemoized(() => context.locale.toLanguageTag());
    final selectedCity = useState<String?>(selectedCityId);
    final selectedTown = useState<String?>(selectedTownId);
    final citiesAsync = ref.watch(citiesProvider);
    final townsAsync = ref.watch(townsProvider(selectedCity.value));

    const minSize = SheetOffset(0.6);
    const halfSize = SheetOffset(0.7);
    const fullSize = SheetOffset(0.88);

    return NotificationListener<SheetDragUpdateNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (notification.dragDetails.deltaY > 0 &&
            metrics.offset <= metrics.minOffset + 0.5) {
          Navigator.of(context).maybePop();
          return true;
        }
        return false;
      },
      child: Sheet(
        initialOffset: halfSize,
        scrollConfiguration: const SheetScrollConfiguration(
          scrollSyncMode: SheetScrollHandlingBehavior.always,
          thresholdVelocityToInterruptBallisticScroll: 0.5,
        ),
        decoration: MaterialSheetDecoration(
          color: context.surface,
          size: SheetSize.stretch,
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
        ),
        snapGrid: const SheetSnapGrid(snaps: [minSize, halfSize, fullSize]),
        child: SheetContentScaffold(
          backgroundColor: Colors.transparent,
          bottomBarVisibility: BottomBarVisibility.conditional(
            isVisible: (m) => m.offset >= const SheetOffset(0.6).resolve(m),
          ),
          extendBodyBehindBottomBar: true,
          bottomBar: Container(
            height: 24.w,
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              color: context.surface,
              border: Border(
                top: BorderSide(width: 0.1, color: context.outline),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 4.w).copyWith(top: 3.w),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    height: 11.w,
                    borderRadius: BorderRadius.circular(100.w),
                    text: LocaleKeys.buttons_reset.tr(),
                    onPress: () {
                      selectedCity.value = null;
                      selectedTown.value = null;
                      onApply(null, null);
                      Navigator.pop(context);
                    },
                  ),
                ),
                Gap(2.w),
                Expanded(
                  child: PrimaryButton(
                    height: 11.w,
                    borderRadius: BorderRadius.circular(100.w),
                    text: LocaleKeys.buttons_apply.tr(),
                    onPress: () {
                      onApply(selectedCity.value, selectedTown.value);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 3.w, bottom: 1.w),
                height: 1.w,
                width: 14.w,
                decoration: BoxDecoration(
                  color: context.outline,
                  borderRadius: BorderRadius.circular(100.w),
                ),
              ),
              Gap(4.w),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Text(
                  LocaleKeys.buttons_filter.tr(),
                  style: context.label2SemiBold,
                ),
              ),
              Gap(4.w),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                  ).copyWith(bottom: 64.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // City Selection
                      Text(
                        LocaleKeys.labels_city.tr(),
                        style: context.labelSemiBold,
                      ),
                      Gap(4.w),
                      citiesAsync.when(
                        data: (cities) {
                          return Column(
                            children: [
                              CustomTile(
                                title: LocaleKeys.labels_all.tr(),
                                isSelected: selectedCity.value == null,
                                onTap: () {
                                  selectedCity.value = null;
                                  selectedTown.value = null;
                                },
                              ),
                              ...cities.map(
                                (city) => CustomTile(
                                  title: city.getTitle(locale),
                                  isSelected: selectedCity.value == city.id,
                                  onTap: () {
                                    if (selectedCity.value == city.id) {
                                      selectedCity.value = null;
                                      selectedTown.value = null;
                                    } else {
                                      selectedCity.value = city.id;
                                      selectedTown.value = null;
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            return CustomTile(title: "", isSkeleton: true);
                          },
                        ),
                        error: (error, stack) =>
                            Text(error.toString(), style: context.body),
                      ),

                      // Town Selection (only if city is selected)
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: selectedCity.value != null
                            ? Column(
                                key: ValueKey(selectedCity.value),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Gap(6.w),
                                  Text(
                                    LocaleKeys.labels_town.tr(),
                                    style: context.labelSemiBold,
                                  ),
                                  Gap(4.w),
                                  townsAsync == null || townsAsync.isEmpty
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 4.w,
                                          ),
                                          child: Text(
                                            LocaleKeys.empty_emptyCompany.tr(),
                                            style: context.body,
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            CustomTile(
                                              title: LocaleKeys.labels_all.tr(),
                                              isSelected:
                                                  selectedTown.value == null,
                                              onTap: () {
                                                selectedTown.value = null;
                                              },
                                            ),
                                            ...townsAsync.map(
                                              (town) => CustomTile(
                                                title: town.getTitle(locale),
                                                isSelected:
                                                    selectedTown.value ==
                                                    town.id,
                                                onTap: () {
                                                  if (selectedTown.value ==
                                                      town.id) {
                                                    selectedTown.value = null;
                                                  } else {
                                                    selectedTown.value =
                                                        town.id;
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                ],
                              )
                            : SizedBox(key: ValueKey('empty')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
