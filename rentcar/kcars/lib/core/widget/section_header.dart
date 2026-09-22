import 'package:flutter/material.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:sizer/sizer.dart';

/// Eyebrow-style section header: uppercase mono label + optional trailing
/// action link, matching the "VIP · FEATURED" / "NEARBY" pattern used across
/// the Home screen and lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: context.overline.copyWith(
              fontFamily: 'jetbrains-mono',
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: context.onSurfaceVariant,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                action!.toUpperCase(),
                style: context.overline.copyWith(
                  fontFamily: 'jetbrains-mono',
                  fontWeight: FontWeight.w500,
                  letterSpacing: .8,
                  color: context.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
