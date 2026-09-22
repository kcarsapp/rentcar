import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_city_filter.g.dart';

/// Normalizes a city's English name for matching — the cars endpoint only
/// returns city NAMES (en/ku/ar) on car.location, never ids, so the Home
/// narrowing has to key on the English name.
String cityKey(String en) => en.trim().toLowerCase();

/// Which cities the Home car list is narrowed to, keyed by [cityKey].
/// Empty = all cities.
///
/// This is deliberately separate from the search screen's [Filters] state:
/// a company belongs to a city and its cars inherit that address, so this
/// is an in-place narrowing of the Home feed only — it never navigates to
/// the search screen and never touches the (paid) Featured placements.
@riverpod
class HomeCityFilter extends _$HomeCityFilter {
  @override
  Set<String> build() => {};

  void setCities(Set<String> cityKeys) => state = cityKeys;

  void clear() => state = {};
}
