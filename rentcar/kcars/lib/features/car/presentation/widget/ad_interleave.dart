import 'package:kcars/features/app_settings/data/model/sliders.dart';

/// One slot in a list that's either a real item or a dropped-in ad.
class AdSlot<T> {
  const AdSlot.item(this.item) : ad = null;
  const AdSlot.ad(this.ad) : item = null;

  final T? item;
  final Sliders? ad;
  bool get isAd => ad != null;
}

/// Number of visible car listings between sponsored placements.
const carsBeforeAd = 16;

/// Inserts one ad after every [every] real items, including after a complete
/// final group. Cycles through [ads] if there are more ad slots than distinct
/// ads available.
List<AdSlot<T>> interleaveAds<T>(
  List<T> items,
  List<Sliders> ads, {
  int every = carsBeforeAd,
}) {
  if (items.isEmpty || ads.isEmpty) {
    return items.map((e) => AdSlot<T>.item(e)).toList();
  }
  final adCount = items.length ~/ every;
  if (adCount <= 0) {
    return items.map((e) => AdSlot<T>.item(e)).toList();
  }
  final result = <AdSlot<T>>[];
  var adIndex = 0;
  for (var i = 0; i < items.length; i++) {
    result.add(AdSlot<T>.item(items[i]));
    if ((i + 1) % every == 0 && adIndex < adCount) {
      result.add(AdSlot<T>.ad(ads[adIndex % ads.length]));
      adIndex++;
    }
  }
  return result;
}
