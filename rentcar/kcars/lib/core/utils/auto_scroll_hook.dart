import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A ScrollController that periodically animates itself forward by
/// [itemExtent], looping back to the start once it reaches the end —
/// used to auto-advance horizontal car-card rows the way the promo image
/// slider already auto-plays.
ScrollController useAutoScrollController({
  required bool enabled,
  required double itemExtent,
  Duration interval = const Duration(seconds: 4),
  Duration animationDuration = const Duration(milliseconds: 900),
}) {
  final controller = useScrollController();

  useEffect(() {
    if (!enabled || itemExtent <= 0) return null;

    final timer = Timer.periodic(interval, (_) {
      if (!controller.hasClients) return;
      final position = controller.position;
      if (position.isScrollingNotifier.value) return;

      final next = controller.offset + itemExtent;
      if (next >= position.maxScrollExtent) {
        controller.animateTo(
          0,
          duration: animationDuration,
          curve: Curves.easeInOut,
        );
      } else {
        controller.animateTo(
          next,
          duration: animationDuration,
          curve: Curves.easeInOut,
        );
      }
    });

    return timer.cancel;
  }, [enabled, itemExtent]);

  return controller;
}
