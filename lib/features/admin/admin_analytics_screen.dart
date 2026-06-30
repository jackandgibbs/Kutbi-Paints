import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../services/report_service.dart';
import '../../core/services/haptic_service.dart';
import '../shared/widgets/skeleton_loaders.dart';
import '../shared/widgets/product_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/lottie_loading_widget.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final weeklyData = ds.getWeeklyRevenueData();
    final brandBreakdown = ds.getBrandRevenueBreakdown();
    final demands = ds.getDemandForecast();
    final lowStockAlerts = ds.getLowStockAlerts();

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading analytics...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Export CSV',
            onPressed: () {
              HapticService.medium();
              final orders = ds.getAllOrders();
              ReportService.exportOrdersCSV(orders, ds);
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
                   SizedBox(height: 20),
                   ChartPlaceholderSkeleton(height: 200),
                   SizedBox(height: 28),
                   ChartPlaceholderSkeleton(height: 280),
                   SizedBox(height: 28),
                   ChartPlaceholderSkeleton(height: 150),
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
            // ─── WEEKLY REVENUE CHART ──────────────────────
            _sectionTitle('Weekly Revenue', Icons.bar_chart_rounded),
            const SizedBox(height: 12),
            _buildRevenueChart(weeklyData),
            const SizedBox(height: 28),

            // ─── BRAND BREAKDOWN PIE CHART ─────────────────
            _sectionTitle('Brand Revenue Split', Icons.pie_chart_rounded),
            const SizedBox(height: 12),
            _buildBrandPieChart(brandBreakdown),
            const SizedBox(height: 28),

            // ─── LOW STOCK ALERTS ──────────────────────────
            if (lowStockAlerts.isNotEmpty) ...[
              _sectionTitle(
                  'Low Stock Alerts (${lowStockAlerts.length})',
                  Icons.warning_amber_rounded),
              const SizedBox(height: 12),
              ...lowStockAlerts.take(5).map((a) => _lowStockCard(a)),
              const SizedBox(height: 28),
            ],

            // ─── DEMAND FORECAST TABLE ─────────────────────
            _sectionTitle('Demand Forecast (Next 30 Days)', Icons.trending_up_rounded),
            const SizedBox(height: 12),
            _buildForecastTable(demands),
            const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.adminPrimary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── REVENUE BAR CHART ──────────────────────────────────────
  Widget _buildRevenueChart(List<Map<String, dynamic>> data) {
    final maxRevenue = data.fold(0.0,
        (max, d) => (d['revenue'] as double) > max ? d['revenue'] as double : max);
    final yMax = (maxRevenue > 0 ? maxRevenue * 1.3 : 10000).toDouble();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          maxY: yMax,
          barGroups: List.generate(data.length, (i) {
            final revenue = data[i]['revenue'] as double;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: revenue,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                  ),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _formatCompact(value),
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textLight),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Text(
                    data[i]['dayLabel'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '₹${_formatCompact(rod.toY)}\n${data[groupIndex]['orders']} orders',
                  GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── BRAND PIE CHART ────────────────────────────────────────
  Widget _buildBrandPieChart(List<Map<String, dynamic>> data) {
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: data.isEmpty
          ? Center(
              child: Text(
                'No order data yet',
                style: GoogleFonts.poppins(color: AppColors.textLight),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: List.generate(data.length, (i) {
                        final d = data[i];
                        return PieChartSectionData(
                          value: d['revenue'] as double,
                          title: '${(d['percentage'] as double).toStringAsFixed(0)}%',
                          titleStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          color: colors[i % colors.length],
                          radius: 60,
                          titlePositionPercentageOffset: 0.6,
                        );
                      }),
                      centerSpaceRadius: 30,
                      sectionsSpace: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(data.length, (i) {
                  final d = data[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d['brand'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${_formatCompact(d['revenue'] as double)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // ─── LOW STOCK ALERT CARD ───────────────────────────────────
  Widget _lowStockCard(Map<String, dynamic> alert) {
    final product = alert['product'];
    final severity = alert['severity'] as String;
    final color = severity == 'critical'
        ? AppColors.error
        : (severity == 'warning' ? AppColors.warning : AppColors.info);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ProductImage(
            imageUrl: product.imageUrl,
            productId: product.id,
            brand: product.brand,
            size: 42,
            borderRadius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${alert['currentStock']} left • ~${alert['daysUntilStockout']} days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Reorder: ${alert['suggestedReorder']}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DEMAND FORECAST TABLE ──────────────────────────────────
  Widget _buildForecastTable(List<Map<String, dynamic>> demands) {
    if (demands.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No order history for forecasting',
            style: GoogleFonts.poppins(color: AppColors.textLight),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.adminPrimary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Product',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Brand',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Predicted',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 40, child: Center(child: Text('Trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
              ],
            ),
          ),
          // Rows
          ...demands.take(10).map((d) {
            final trend = d['trend'] as String;
            final trendIcon = trend == 'rising'
                ? Icons.trending_up_rounded
                : (trend == 'falling' ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
            final trendColor = trend == 'rising'
                ? AppColors.success
                : (trend == 'falling' ? AppColors.error : AppColors.textLight);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        ProductImage(
                          imageUrl: d['productImageUrl'] as String?, // Note: May need to ensure this is in the data map
                          productId: d['productId'] as String,
                          brand: d['brand'] as String,
                          size: 24,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d['productName'] as String,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      d['brand'] as String,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${d['emaPrediction']}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.adminPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Center(child: Icon(trendIcon, color: trendColor, size: 20)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
