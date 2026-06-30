import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// A claymorphic bottom navigation bar with smooth shifting indicator animation.
class LiquidGlassNavbar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidGlassNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LiquidGlassNavbar> createState() => _LiquidGlassNavbarState();
}

class _LiquidGlassNavbarState extends State<LiquidGlassNavbar> {
  static const _items = [
    _NavItemData(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
      color: AppColors.navGlowBlue,
    ),
    _NavItemData(
      activeIcon: Icons.receipt_long_rounded,
      inactiveIcon: Icons.receipt_long_outlined,
      label: 'Orders',
      color: AppColors.navGlowPink,
    ),
    _NavItemData(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'Profile',
      color: AppColors.navGlowGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.of(context).size.width - 32) / _items.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDE8),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            // Outer shadow (bottom-right)
            BoxShadow(
              color: const Color(0xFFD1CCC4).withValues(alpha: 0.7),
              blurRadius: 15,
              offset: const Offset(6, 6),
            ),
            // Inner highlight (top-left)
            const BoxShadow(
              color: Colors.white,
              blurRadius: 15,
              offset: Offset(-6, -6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Animated indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: widget.currentIndex * itemWidth + (itemWidth - 56) / 2,
              top: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _items[widget.currentIndex].color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            // Nav items
            Row(
              children: List.generate(
                _items.length,
                (i) => Expanded(
                  child: _ClayNavItem(
                    data: _items[i],
                    isActive: widget.currentIndex == i,
                    onTap: () => widget.onTap(i),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final Color color;

  const _NavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.color,
  });
}

class _ClayNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _ClayNavItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? data.activeIcon : data.inactiveIcon,
                color: isActive ? data.color : AppColors.textSlateLight,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: isActive ? 11 : 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? data.color : AppColors.textSlateLight,
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
