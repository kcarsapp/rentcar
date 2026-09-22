import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A small, reusable haptic vocabulary so screens do not each choose a
/// different vibration for the same interaction.
abstract final class AppHaptics {
  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> lightTap() => HapticFeedback.lightImpact();
  static Future<void> mediumAction() => HapticFeedback.mediumImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> warning() => HapticFeedback.heavyImpact();
  static Future<void> error() => HapticFeedback.heavyImpact();
}

/// A platform-neutral spring press interaction. It intentionally stays small
/// and composable so it can wrap cards, buttons, and navigation controls.
class SpringPressable extends StatefulWidget {
  const SpringPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .975,
    this.borderRadius,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  @override
  State<SpringPressable> createState() => _SpringPressableState();
}

class _SpringPressableState extends State<SpringPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 420),
    lowerBound: 0,
    upperBound: 1,
  );

  void _press() {
    AppHaptics.lightTap();
    _controller.forward();
  }

  void _release() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = 1 - ((1 - widget.scale) * _controller.value);
        return Transform.scale(scale: value, child: child);
      },
    );
    return Semantics(
      button: widget.onTap != null || widget.onLongPress != null,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      ),
    );
  }
}

/// Frosted control/surface used sparingly for navigation and actions. Large
/// image cards deliberately do not use this to keep scrolling inexpensive.
class IOSGlassSurface extends StatelessWidget {
  const IOSGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = 18,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color? color;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final base =
        color ?? Theme.of(context).colorScheme.surface.withValues(alpha: .60);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base,
            borderRadius: borderRadius,
            border:
                border ??
                Border.all(
                  color: Colors.white.withValues(alpha: .62),
                  width: .7,
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

String carImageHeroTag(String carId) => 'car-image-$carId';
