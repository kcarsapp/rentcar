import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/utils/extensions.dart';

/// A floating navigation surface whose selection follows the actual route.
class CustomBottomNavigationBar extends StatelessWidget {
  const CustomBottomNavigationBar({
    super.key,
    required this.onTap,
    required this.tabs,
    this.activeIndex = 0,
  });
  final ValueChanged<int> onTap;
  final List<BottmBarModel> tabs;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(32, 2, 32, 6),
      child: IOSGlassSurface(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final selected = index == activeIndex;
            final color = selected ? context.primary : const Color(0xFF667085);
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                child: SpringPressable(
                  onTap: () {
                    AppHaptics.selection();
                    onTap(index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: selected
                              ? const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.primaryContainer.withValues(
                                    alpha: .92,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: selected
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      tab.activeIcon,
                                      height: 20,
                                      width: 20,
                                      colorFilter: ColorFilter.mode(
                                        color,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        tab.lable,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.label.copyWith(
                                          fontSize: 10,
                                          color: color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SvgPicture.asset(
                                  tab.icon,
                                  height: 19,
                                  width: 19,
                                  colorFilter: ColorFilter.mode(
                                    color,
                                    BlendMode.srcIn,
                                  ),
                                ),
                        ),
                        if (!selected) ...[
                          const SizedBox(height: 1),
                          Text(
                            tab.lable,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.label.copyWith(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class BottmBarModel {
  final String lable;
  final String icon;
  final String activeIcon;
  BottmBarModel({
    required this.lable,
    required this.icon,
    required this.activeIcon,
  });
}
