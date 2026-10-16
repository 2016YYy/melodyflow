import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 底部菜单项（未选中图标 / 选中图标 / 文字）
class IntegratedNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const IntegratedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 文字图标一体的底部菜单栏
/// 点击时图标（描边→填充）与文字（颜色/字重）同步变化
class IntegratedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IntegratedNavItem> items;
  final ThemePalette palette;

  const IntegratedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NavCell(
                  item: items[i],
                  selected: i == currentIndex,
                  palette: palette,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final IntegratedNavItem item;
  final bool selected;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _NavCell({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? palette.primary.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: selected ? palette.primary : muted,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? palette.primary : muted,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
