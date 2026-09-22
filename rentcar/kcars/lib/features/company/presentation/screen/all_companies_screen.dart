import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/utils/pagin_list_view.dart';
import 'package:kcars/core/widget/app_bar.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/core/widget/profile_container.dart';
import 'package:kcars/core/widget/search_feild.dart';
import 'package:kcars/features/company/data/model/company.dart';
import 'package:kcars/features/company/presentation/riverpod/all_companies.dart';
import 'package:kcars/features/company/presentation/widget/company_context_preview.dart';
import 'package:kcars/translations/locale_keys.g.dart';
import 'package:sizer/sizer.dart';

@RoutePage()
class AllCompaniesScreen extends HookConsumerWidget {
  const AllCompaniesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final query = useState('');
    return Scaffold(
      appBar: HomeAppBar(),
      // The public mobile app now has one company directory. The old
      // local/international split made the same company appear in two places
      // and is no longer part of the web experience.
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.w, 4.w, 1.w),
            child: Row(
              children: [
                Expanded(
                  child: SearchFeild(
                    controller: searchController,
                    hint: 'Search companies',
                    onChanged: (value) => query.value = value,
                  ),
                ),
                Gap(2.w),
                Container(
                  width: 11.w,
                  height: 11.w,
                  decoration: BoxDecoration(
                    color: context.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.business_rounded, color: context.primary),
                ),
              ],
            ),
          ),
          Expanded(child: AllCompaniesView(query: query.value)),
        ],
      ),
    );
  }
}

class AllCompaniesView extends ConsumerWidget {
  const AllCompaniesView({super.key, this.inl = false, this.query = ''});
  final bool inl;
  final String query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(allCompaniesProvider(inl));
    final normalizedQuery = query.trim().toLowerCase();
    final filteredState = companiesAsync.copyWith(
      items: companiesAsync.items
          .where(
            (company) =>
                !_isPersonalCompany(company) &&
                (normalizedQuery.isEmpty ||
                    company.name.toLowerCase().contains(normalizedQuery)),
          )
          .toList(),
      error: companiesAsync.error,
    );
    return GridPagingSliverList(
      emptyMessage: LocaleKeys.empty_emptyCompany.tr(),
      padding: EdgeInsets.symmetric(
        horizontal: 4.w,
      ).copyWith(bottom: 26.w, top: 4.w),
      onRefresh: () =>
          ref.read(allCompaniesProvider(inl).notifier).loadInitial(),
      onLoadMore: () => ref.read(allCompaniesProvider(inl).notifier).loadMore(),
      state: filteredState,
      itemBuilder: (context, item, index) {
        return CompanyWidget(company: item);
      },
    );
  }

  /// Personal owners use a synthetic Company record internally so their cars
  /// can participate in the rental flow. They belong in car results, not the
  /// public company directory.
  bool _isPersonalCompany(Company company) {
    final name = company.name.trim().toLowerCase();
    return company.profile?.isPersonal == true ||
        name.endsWith('· personal cars') ||
        name.endsWith('· personal car') ||
        name.endsWith(' personal cars') ||
        name.endsWith(' personal car');
  }
}

class CompanyWidget extends StatelessWidget {
  const CompanyWidget({super.key, required this.company});
  final Company company;
  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      semanticsLabel: company.name,
      onTap: () {
        context.router.push(CompanyDetailsRoute(companyId: company.id));
      },
      onLongPress: () => showCompanyContextPreview(context, company),
      child: Material(
        clipBehavior: Clip.hardEdge,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(14.w),
          side: BorderSide(color: context.surfaceContainer, width: 0.3),
        ),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 32.w,
                child: Stack(
                  children: [
                    ImageHolder(
                      aspectRation: 16 / 9,
                      padding: EdgeInsets.zero,
                      fit: BoxFit.cover,
                      image: company.coverImage,
                      height: 24.w,
                      width: 100.w,
                      borderRadius: BorderRadius.zero,
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ProfileContainer(
                          child: ImageHolder(
                            width: 20.w,
                            height: 20.w,
                            image: company.image,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(100.w),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(1.w),
                child: Text(
                  company.name,
                  style: context.labelSemiBold,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
