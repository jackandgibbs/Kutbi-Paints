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

class AdminBillsTab extends ConsumerStatefulWidget {
  const AdminBillsTab({super.key});

  @override
  ConsumerState<AdminBillsTab> createState() => _AdminBillsTabState();
}

class _AdminBillsTabState extends ConsumerState<AdminBillsTab> {
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final pendingBills = ds.getOrdersForBilling().length;
    final cashPending = ds.getCashPendingOrders().length;
    final onlinePending = ds.getOnlinePendingOrders().length;
    final activeOrders = ds.getOrdersByStatus('accepted').length;

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.adminBg,
        body: LottieLoadingWidget(message: 'Loading bills...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: RefreshIndicator(
        color: const Color(0xFFF97316),
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
                  'Bills & Payments',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSlate,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage payments, billing, and orders',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSlateLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Payments Card
                _claymorphicActionCard(
                  icon: Icons.payments_rounded,
                  title: 'Payments',
                  subtitle: 'Verify & confirm payments',
                  glowColor: const Color(0xFF059669),
                  badgeText: (cashPending + onlinePending) > 0
                      ? '${cashPending + onlinePending} pending'
                      : null,
                  badgeColor: const Color(0xFF059669),
                  onTap: () => context.push('/admin/payments'),
                  index: 0,
                ),
                const SizedBox(height: 18),

                // Pending Bills Card
                _claymorphicActionCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Pending Bills',
                  subtitle: 'Generate and manage bills',
                  glowColor: AppColors.adminAccent,
                  badgeText: pendingBills > 0 ? '$pendingBills pending' : null,
                  badgeColor: AppColors.adminAccent,
                  onTap: () => context.push('/admin/pending-bills'),
                  index: 1,
                ),
                const SizedBox(height: 18),

                // Generated Bills Card
                _claymorphicActionCard(
                  icon: Icons.history_rounded,
                  title: 'Generated Bills',
                  subtitle: 'View accepted & deleted orders',
                  glowColor: const Color(0xFF7C3AED),
                  onTap: () => context.push('/admin/generated-bills'),
                  index: 2,
                ),
                const SizedBox(height: 18),

                // Orders Card
                _claymorphicActionCard(
                  icon: Icons.local_shipping_rounded,
                  title: 'Orders',
                  subtitle: 'Manage & track all orders',
                  glowColor: const Color(0xFF7C3AED),
                  badgeText: activeOrders > 0 ? '$activeOrders active' : null,
                  badgeColor: const Color(0xFF7C3AED),
                  onTap: () => context.push('/admin/orders'),
                  index: 3,
                ),
                const SizedBox(height: 18),

                // Reset PINs Card
                _claymorphicActionCard(
                  icon: Icons.lock_reset_rounded,
                  title: 'Reset PINs',
                  subtitle: 'Change painter login PINs',
                  glowColor: const Color(0xFFF43F5E),
                  onTap: () => context.push('/admin/reset-pin'),
                  index: 4,
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
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 16,
                offset: const Offset(-6, -6),
              ),
              BoxShadow(
                color: const Color(0xFFD1CCC4).withOpacity(0.7),
                blurRadius: 16,
                offset: const Offset(6, 6),
              ),
              BoxShadow(
                color: glowColor.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: glowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 6,
                      offset: const Offset(-2, -2),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
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
