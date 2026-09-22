import 'package:kcars/features/company/data/model/company.dart';
import 'package:kcars/features/company/presentation/riverpod/all_companies.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filtered_companies.g.dart';

enum InternationalFilter { all, international, domestic }

@riverpod
class FilteredCompanies extends _$FilteredCompanies {
  @override
  List<Company> build() {
    return [];
  }

  void filterCompanies({
    String? searchQuery,
    InternationalFilter? internationalFilter,
    String? cityId,
    String? townId,
  }) {
    final allCompanies = ref.read(allCompaniesProvider).items;
    var filtered = List<Company>.from(allCompanies);

    // Apply international filter
    if (internationalFilter != null &&
        internationalFilter != InternationalFilter.all) {
      filtered = filtered.where((company) {
        if (internationalFilter == InternationalFilter.international) {
          return company.international == true;
        } else if (internationalFilter == InternationalFilter.domestic) {
          return company.international != true;
        }
        return true;
      }).toList();
    }

    // Apply city filter
    if (cityId != null && cityId.isNotEmpty) {
      filtered = filtered.where((company) {
        final location = company.location;
        if (location == null) return false;
        return location.cityId != null && location.cityId == cityId;
      }).toList();
    }

    // Apply town filter (only if city is also selected or we want to filter by town only)
    if (townId != null && townId.isNotEmpty) {
      filtered = filtered.where((company) {
        final location = company.location;
        if (location == null) return false;
        return location.townId != null && location.townId == townId;
      }).toList();
    }

    // Apply search query filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((company) {
        return company.name.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by index (nulls last), then by name as fallback
    filtered.sort((a, b) {
      if (a.index == null && b.index == null) {
        return a.name.compareTo(b.name);
      }
      if (a.index == null) return 1;
      if (b.index == null) return -1;
      return b.index!.compareTo(a.index!);
    });

    state = filtered;
  }
}
