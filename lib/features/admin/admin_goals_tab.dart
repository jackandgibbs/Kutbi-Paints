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

class AdminGoalsTab extends ConsumerStatefulWidget {
  const AdminGoalsTab({super.key});

  @override
  ConsumerState<AdminGoalsTab> createState() => _AdminGoalsTabState();
}

class _AdminGoalsTabState extends ConsumerState<AdminGoalsTab> {
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final activePromotions = ds.getActivePromotions().length;

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.adminBg,
        body: LottieLoadingWidget(message: 'Loading goals...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: RefreshIndicator(
        color: const Color(0xFF10B981),
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
                    'Goals & Analytics',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSlate,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage offers, targets, and view analytics',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSlateLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Offers Card
                  _claymorphicActionCard(
                    icon: Icons.campaign_rounded,
                    title: 'Offers',
                    subtitle: 'Manage promotions & campaigns',
                    glowColor: const Color(0xFFF97316),
                    badgeText: activePromotions > 0
                        ? '$activePromotions active'
                        : null,
                    badgeColor: const Color(0xFFF97316),
                    onTap: () => context.push('/admin/promotions'),
                    index: 0,
                  ),
                  const SizedBox(height: 18),

                  // Goals Card
                  _claymorphicActionCard(
                    icon: Icons.flag_rounded,
                    title: 'Goals',
                    subtitle: 'Set monthly targets for painters',
                    glowColor: const Color(0xFF10B981),
                    onTap: () => context.push('/admin/goals'),
                    index: 1,
                  ),
                  const SizedBox(height: 18),

                  // Reward Milestones Card
                  _claymorphicActionCard(
                    icon: Icons.star_rounded,
                    title: 'Reward Milestones',
                    subtitle: 'Configure point-based rewards & view painter progress',
                    glowColor: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/admin/reward-points'),
                    index: 2,
                  ),
                  const SizedBox(height: 18),

                  // Analytics Card
                  _claymorphicActionCard(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics',
                    subtitle: 'Charts, reports & deep insights',
                    glowColor: const Color(0xFF3B82F6),
                    onTap: () => context.push('/admin/analytics'),
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
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 16,
                offset: const Offset(-6, -6),
              ),
              BoxShadow(
                color: const Color(0xFFD1CCC4).withValues(alpha: 0.7),
                blurRadius: 16,
                offset: const Offset(6, 6),
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: 0.08),
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
                  color: glowColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 6,
                      offset: const Offset(-2, -2),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withValues(alpha: 0.4),
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
                          color: (badgeColor ?? glowColor).withValues(alpha: 0.12),
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
                color: AppColors.textSlateLight.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
