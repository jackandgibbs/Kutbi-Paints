import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';

class UserActivityScreen extends ConsumerWidget {
  final String painterId;
  const UserActivityScreen({super.key, required this.painterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final painter = ds.getUserById(painterId);
    final orders = ds.getOrdersByPainter(painterId);
    final lifetimeValue = ds.getPainterLifetimeValue(painterId);
    final brandBreakdown = ds.getPainterBrandBreakdown(painterId);
    final rewards = ds.getRewardsForPainter(painterId);

    if (painter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Activity')),
        body: const Center(child: Text('Painter not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text('Painter Insights',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Painter Card - Premium Design
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: (painter.profileImageUrl != null &&
                            painter.profileImageUrl!.isNotEmpty)
                        ? Image.network(
                            painter.profileImageUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                painter.name[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              painter.name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(painter.name,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            )),
                        Text(painter.businessName ?? 'Independent Painter',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 12, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text(painter.phone,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _tierBadge(painter.tier),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                _miniStat('Total Orders', '${orders.length}',
                    Icons.receipt_long_rounded, const Color(0xFF6366F1)),
                const SizedBox(width: 16),
                _miniStat(
                    'Lifetime Value',
                    '₹${NumberFormat('#,##0').format(lifetimeValue)}',
                    Icons.trending_up_rounded,
                    const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 32),

            // Brand Breakdown
            _sectionHeader('Brand Preference'),
            const SizedBox(height: 12),
            if (brandBreakdown.isEmpty)
              _emptyState('No purchase breakdown available')
            else
              ...brandBreakdown.entries.map((e) => _brandBreakdownCard(e.key, e.value, brandBreakdown)),
            
            const SizedBox(height: 32),

            // Earned Rewards
            _sectionHeader('Earned Rewards', icon: Icons.stars_rounded, iconColor: const Color(0xFFFFD700)),
            const SizedBox(height: 12),
            if (rewards.isEmpty)
              _emptyState('No rewards earned yet')
            else
              ...rewards.map((reward) => _rewardCard(context, ref, reward, ds)),
            
            const SizedBox(height: 32),

            // Order History
            _sectionHeader('Recent Purchases'),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              _emptyState('No purchase history')
            else
              ...orders.map((order) => _purchaseHistoryCard(order)),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _tierBadge(String tier) {
    final isGold = tier.toLowerCase() == 'gold';
    final color = isGold ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tier.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 20),
        ],
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _brandBreakdownCard(String brand, int count, Map<String, int> all) {
    final brandColor = AppColors.getBrandPrimary(brand);
    final maxQty = all.values.fold(0, (max, v) => v > max ? v : max);
    final ratio = maxQty > 0 ? count / maxQty : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(brand, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('$count buckets', 
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: brandColor)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(brandColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard(BuildContext context, WidgetRef ref, dynamic reward, DataService ds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB8860B), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ds.getGoalById(reward.goalId)?.title ?? 'Goal Reward', 
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Earned ${DateFormat('dd MMM yy').format(reward.earnedAt)}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${reward.rewardAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
              InkWell(
                onTap: () => _confirmDeleteReward(context, ref, reward),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Remove', 
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _purchaseHistoryCard(dynamic order) {
    final brandColor = AppColors.getBrandPrimary(order.brand);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.shopping_bag_rounded, color: brandColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.brand, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${order.items.length} items • ${DateFormat('dd MMM').format(order.createdAt)}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${order.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              _statusMiniBadge(order.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusMiniBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  void _confirmDeleteReward(BuildContext context, WidgetRef ref, dynamic reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove Reward?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove this reward? This will be deducted from the painter\'s balance.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(dataServiceProvider).deleteReward(reward.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Reward removed successfully'), 
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Remove', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'placed': return const Color(0xFF6366F1);
      case 'accepted': return const Color(0xFF10B981);
      case 'preparing': return const Color(0xFFF59E0B);
      case 'dispatched': return const Color(0xFF8B5CF6);
      case 'delivered': return const Color(0xFF10B981);
      default: return AppColors.textSecondary;
    }
  }
}
