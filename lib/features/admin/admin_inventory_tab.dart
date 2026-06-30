import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_support.dart';
import '../../core/utils/responsive.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';
import '../shared/widgets/skeleton_loaders.dart';

class AdminInventoryTab extends ConsumerStatefulWidget {
  const AdminInventoryTab({super.key});

  @override
  ConsumerState<AdminInventoryTab> createState() => _AdminInventoryTabState();
}

class _AdminInventoryTabState extends ConsumerState<AdminInventoryTab> {
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final painters = ds.getAllPainters();
    final pendingPainters = painters.where((p) => p.status == 'inactive').length;
    final productsCount = ds.getAllProducts().length;
    final lowStockCount = ds.getLowStockAlerts().length;

    if (!ds.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: BrandCardSkeleton(),
              )),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: RefreshIndicator(
        color: const Color(0xFF0EA5E9),
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 24, Responsive.horizontalPadding(context), Responsive.isDesktop(context) ? 40 : 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Inventory & Painters',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSlate,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your stock and painter registrations',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSlateLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Inventory Card
                  _claymorphicActionCard(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    subtitle: '$productsCount products registered',
                    glowColor: const Color(0xFF0EA5E9),
                    badgeText: lowStockCount > 0 ? '$lowStockCount low stock' : null,
                    badgeColor: const Color(0xFFD97706),
                    onTap: () => context.push('/admin/inventory'),
                    index: 0,
                  ),
                  const SizedBox(height: 18),

                  // Painters Card
                  _claymorphicActionCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Painters',
                    subtitle: '${painters.length} registered painters',
                    glowColor: const Color(0xFF8B5CF6),
                    badgeText: pendingPainters > 0 ? '$pendingPainters pending' : null,
                    badgeColor: AppColors.adminAccent,
                    onTap: () => context.push('/admin/users'),
                    index: 1,
                  ),
                  const SizedBox(height: 18),

                  // Stock Management Card
                  _claymorphicActionCard(
                    icon: Icons.inventory_rounded,
                    title: 'Stock Management',
                    subtitle: 'Manage litre variants & quantities',
                    glowColor: const Color(0xFF10B981),
                    badgeText: ds.getLowStockAlerts().isNotEmpty ? 'Updates needed' : null,
                    badgeColor: const Color(0xFFF59E0B),
                    onTap: () => context.push('/admin/stock-management'),
                    index: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _claymorphicActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color glowColor,
    String? badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
    required int index,
  }) {
    final isPressed = _pressedIndex == index;
    return GestureDetector(
      onTapDown: (_) {
        if (PlatformSupport.supportsHaptics) HapticFeedback.mediumImpact();
        setState(() => _pressedIndex = index);
      },
      onTapUp: (_) {
        setState(() => _pressedIndex = null);
        onTap();
      },
      onTapCancel: () => setState(() => _pressedIndex = null),
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              // Icon container with inner shadow
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: glowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: glowColor, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSlate,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSlateLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? glowColor).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor ?? glowColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSlateLight.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
