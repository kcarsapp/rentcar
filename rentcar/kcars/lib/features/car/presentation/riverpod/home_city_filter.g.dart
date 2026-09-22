// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_city_filter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeCityFilterHash() => r'3dc833ed8bc4afab1e6cf55a9eabf1f5deebc5e4';

/// Which cities the Home car list is narrowed to, keyed by [cityKey].
/// Empty = all cities.
///
/// This is deliberately separate from the search screen's [Filters] state:
/// a company belongs to a city and its cars inherit that address, so this
/// is an in-place narrowing of the Home feed only — it never navigates to
/// the search screen and never touches the (paid) Featured placements.
///
/// Copied from [HomeCityFilter].
@ProviderFor(HomeCityFilter)
final homeCityFilterProvider =
    AutoDisposeNotifierProvider<HomeCityFilter, Set<String>>.internal(
      HomeCityFilter.new,
      name: r'homeCityFilterProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homeCityFilterHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HomeCityFilter = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
