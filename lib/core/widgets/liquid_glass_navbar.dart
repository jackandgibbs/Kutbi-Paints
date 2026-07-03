import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// A claymorphic bottom navigation bar with smooth shifting indicator animation.
/// Supports an optional badge count per item (e.g. cart item count).
class LiquidGlassNavbar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Optional badge counts, indexed to match the nav items.
  /// A value of 0 means no badge is shown for that item.
  final List<int> badgeCounts;

  const LiquidGlassNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts = const [],
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
      activeIcon: Icons.shopping_cart_rounded,
      inactiveIcon: Icons.shopping_cart_outlined,
      label: 'Cart',
      color: Color(0xFFFF9500),
    ),
    _NavItemData(
      activeIcon: Icons.account_balance_wallet_rounded,
      inactiveIcon: Icons.account_balance_wallet_outlined,
      label: 'Earnings',
      color: Color(0xFF10B981),
    ),
    _NavItemData(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'Profile',
      color: AppColors.navGlowGreen,
    ),
  ];

  int _badgeFor(int i) {
    if (i < widget.badgeCounts.length) return widget.badgeCounts[i];
    return 0;
  }

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
            BoxShadow(
              color: const Color(0xFFD1CCC4).withValues(alpha: 0.7),
              blurRadius: 15,
              offset: const Offset(6, 6),
            ),
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
              left: widget.currentIndex * itemWidth + (itemWidth - 52) / 2,
              top: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
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
                    badge: _badgeFor(i),
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
  final int badge;
  final VoidCallback onTap;

  const _ClayNavItem({
    required this.data,
    required this.isActive,
    required this.badge,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isActive ? data.activeIcon : data.inactiveIcon,
                    color: isActive ? data.color : AppColors.textSlateLight,
                    size: 22,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF0EDE8), width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 13),
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: isActive ? 9.5 : 8.5,
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
