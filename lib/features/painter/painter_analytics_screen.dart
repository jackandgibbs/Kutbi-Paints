import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/report_service.dart';
import '../../core/services/haptic_service.dart';
import '../shared/widgets/skeleton_loaders.dart';
import '../shared/widgets/product_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class PainterAnalyticsScreen extends ConsumerWidget {
  const PainterAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final spendingTrend = ds.getMonthlySpendingTrend(user.id);
    final brandBreakdown = ds.getBrandBreakdownForPainter(user.id);
    final goldSavings = ds.getGoldSavings(user.id);
    final topProducts = ds.getTopOrderedProducts(user.id);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('My Performance',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF',
            onPressed: () {
              HapticService.medium();
              final totalSpend = ds.getTotalSpendForPainter(user.id);
              ReportService.exportPainterPerformancePDF(
                painterName: user.name,
                totalSpend: totalSpend,
                goldSavings: goldSavings,
                brandBreakdown: {
                  for (var b in brandBreakdown) b['brand'] as String: b['revenue'] as double
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !ds.isLoaded
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  ChartPlaceholderSkeleton(height: 120),
                  SizedBox(height: 28),
                  ChartPlaceholderSkeleton(height: 240),
                  SizedBox(height: 28),
                  ChartPlaceholderSkeleton(height: 300),
                ],
              ),
            )
          : AnimationLimiter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
            // ─── SAVINGS CARD ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Gold Savings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₹${goldSavings.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved this year via tier discounts',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ─── MONTHLY SPENDING TREND ───────────────────
            Text(
              'Spending Trend (Last 6 Mos)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(spendingTrend),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(0)}',
                          GoogleFonts.poppins(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _formatCompact(value),
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: AppColors.textLight),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= spendingTrend.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              spendingTrend[value.toInt()]['month'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getMaxY(spendingTrend) / 4 > 0 ? _getMaxY(spendingTrend) / 4 : 1000,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: spendingTrend.asMap().entries.map((e) {
                    final isHighest = e.value['spend'] == _getMaxY(spendingTrend) && _getMaxY(spendingTrend) > 0;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value['spend'] as double,
                          color: isHighest ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ─── BRAND BREAKDOWN ──────────────────────────
            Text(
              'Brand Preferences',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (brandBreakdown.isEmpty)
              const Center(child: Text('No order history yet'))
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: brandBreakdown.asMap().entries.map((e) {
                            final colors = [
                              const Color(0xFF3B82F6),
                              const Color(0xFF10B981),
                              const Color(0xFFF59E0B),
                              const Color(0xFF8B5CF6),
                              const Color(0xFFEC4899),
                            ];
                            final pct = e.value['percentage'] as double;
                            return PieChartSectionData(
                              color: colors[e.key % colors.length],
                              value: pct,
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: 20,
                              titleStyle: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: brandBreakdown.asMap().entries.map((e) {
                          final colors = [
                            const Color(0xFF3B82F6),
                            const Color(0xFF10B981),
                            const Color(0xFFF59E0B),
                            const Color(0xFF8B5CF6),
                            const Color(0xFFEC4899),
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: colors[e.key % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                      e.value['brand'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // ─── TOP ORDERED PRODUCTS ─────────────────────
            Text(
              'Most Ordered Products',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (topProducts.isEmpty)
              const Center(child: Text('No order history yet'))
            else
              ...topProducts.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        ProductImage(
                          imageUrl: p['imageUrl'] as String?,
                          productId: p['id'] as String,
                          brand: p['brand'] as String,
                          size: 48,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                p['brand'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${p['quantity']}x',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Ordered',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  double _getMaxY(List<Map<String, dynamic>> chartData) {
    double max = 0;
    for (final d in chartData) {
      if ((d['spend'] as double) > max) max = d['spend'] as double;
    }
    return max == 0 ? 1000 : max * 1.2;
  }

  String _formatCompact(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
