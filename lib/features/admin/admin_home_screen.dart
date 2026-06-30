import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/utils/responsive.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';
import '../shared/widgets/product_image.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _lowStockScrollController;
  Timer? _lowStockAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _lowStockScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLowStockAutoScroll();
    });
  }

  @override
  void dispose() {
    _lowStockScrollController.dispose();
    _lowStockAutoScrollTimer?.cancel();
    super.dispose();
  }

  void _startLowStockAutoScroll() {
    _lowStockAutoScrollTimer?.cancel();
    if (_lowStockScrollController.hasClients) {
      _lowStockAutoScrollTimer =
          Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_lowStockScrollController.hasClients) return;
        final max = _lowStockScrollController.position.maxScrollExtent;
        final current = _lowStockScrollController.offset;
        final next = current >= max ? 0.0 : (current + 200.0).clamp(0.0, max);
        _lowStockScrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _pauseLowStockScroll() {
    _lowStockAutoScrollTimer?.cancel();
  }

  void _resumeLowStockScroll() {
    _lowStockAutoScrollTimer?.cancel();
    _startLowStockAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final user = ref.watch(authProvider).user;
    final adminName = user?.name ?? 'System Admin';

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.adminBg,
        body: LottieLoadingWidget(message: 'Loading dashboard...'),
      );
    }

    // Analytics Stats
    final dailyRevenue = ds.getDailyRevenue();
    final todayOrders = ds.getTodayOrdersCount();
    final topPainter = ds.getTopPainter();
    final topProduct = ds.getTopProduct();
    final weeklyData = ds.getWeeklyRevenueData();
    final lowStockAlerts = ds.getLowStockAlerts();

    final dailyTrendPercent = _computeRevenueTrend(weeklyData);
    final dailyTrendUp = dailyTrendPercent >= 0;

    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final dateLabel = _dateLabel(now);

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: RefreshIndicator(
        color: AppColors.adminAccent,
        backgroundColor: Colors.transparent,
        onRefresh: ds.refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: CustomScrollView(
              slivers: [
                // ── HEADER ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSlateLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Admin Pulse',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSlate,
                                      letterSpacing: -0.8,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    adminName.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.adminAccent,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0EDE8),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.7),
                                      blurRadius: 4,
                                      offset: const Offset(-2, -2),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFD1CCC4)
                                          .withOpacity(0.5),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _pill(Icons.calendar_today_rounded, dateLabel),
                              const SizedBox(width: 10),
                              _pill(Icons.circle, 'Live',
                                  iconSize: 8,
                                  color: const Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── TODAY'S OVERVIEW ──────────────────────
                      _sectionLabel("Today's Overview"),
                      const SizedBox(height: 14),

                      if (Responsive.isDesktop(context))
                        _buildDesktopStatsGrid(dailyRevenue, dailyTrendPercent, dailyTrendUp, weeklyData, todayOrders, topPainter, topProduct)
                      else ...[
                        // Revenue card — full width with sparkline (skeuomorphic)
                        _skeuomorphicStatCard(
                          label: 'Daily Revenue',
                          value: '₹${_formatCompact(dailyRevenue)}',
                          valueNumber: dailyRevenue,
                          icon: Icons.currency_rupee_rounded,
                          color: AppColors.adminAccent,
                          bg: AppColors.adminAccentLight,
                          sparklineData: weeklyData,
                          trendPercent: dailyTrendPercent,
                          trendUp: dailyTrendUp,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 14),

                        // Orders today
                        _skeuomorphicStatCard(
                          label: 'Orders Today',
                          value: '$todayOrders',
                          valueNumber: todayOrders.toDouble(),
                          icon: Icons.shopping_bag_rounded,
                          color: AppColors.textSlate,
                          bg: AppColors.adminBorder,
                        ),
                        const SizedBox(height: 14),

                        // Top Painter
                        _skeuomorphicStatCard(
                          label: 'Top Painter',
                          value: topPainter != null
                              ? topPainter['name'] as String
                              : '—',
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFF059669),
                          bg: const Color(0xFFECFDF5),
                          sub: topPainter != null
                              ? '₹${_formatCompact(topPainter['amount'] as double)}'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Top Product
                        _skeuomorphicStatCard(
                          label: 'Top Product',
                          value: topProduct != null
                              ? topProduct['name'] as String
                              : '—',
                          icon: Icons.star_rounded,
                          color: const Color(0xFF7C3AED),
                          bg: const Color(0xFFF5F3FF),
                          sub: topProduct != null
                              ? '${topProduct['quantity']} units'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 28),

                      // ── LOW STOCK ALERTS ────────────────────────
                      if (lowStockAlerts.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFD97706), size: 16),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Low Stock (${lowStockAlerts.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSlate,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 76,
                          child: GestureDetector(
                            onTapDown: (_) => _pauseLowStockScroll(),
                            onTapUp: (_) => _resumeLowStockScroll(),
                            onTapCancel: _resumeLowStockScroll,
                            child: ListView.separated(
                              controller: _lowStockScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: lowStockAlerts.take(5).length,
                              separatorBuilder: (_, _a) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (ctx, i) {
                                final alert = lowStockAlerts[i];
                                final severity = alert['severity'] as String;
                                final color = severity == 'critical'
                                    ? AppColors.adminAccent
                                    : (severity == 'warning'
                                        ? const Color(0xFFD97706)
                                        : AppColors.info);
                                final isCritical = severity == 'critical';
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  width: 190,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0EDE8),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border(
                                      left:
                                          BorderSide(color: color, width: 3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.7),
                                        blurRadius: 6,
                                        offset: const Offset(-3, -3),
                                      ),
                                      BoxShadow(
                                        color: isCritical
                                            ? AppColors.error.withOpacity(0.15)
                                            : const Color(0xFFD1CCC4)
                                                .withOpacity(0.5),
                                        blurRadius: isCritical ? 16 : 8,
                                        offset: const Offset(3, 3),
                                      ),
                                    ],
                                    gradient: isCritical
                                        ? LinearGradient(
                                            colors: [
                                              AppColors.error.withOpacity(0.07),
                                              const Color(0xFFF0EDE8),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      ProductImage(
                                        imageUrl: alert['product'].imageUrl,
                                        productId: alert['product'].id,
                                        brand: alert['product'].brand,
                                        size: 38,
                                        borderRadius: 8,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              alert['product'].name,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textSlate),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${alert['currentStock']} left · ~${alert['daysUntilStockout']}d',
                                              style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: color,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── 7-DAY REVENUE CHART ──────────────────────
                      _sectionLabel('7-Day Revenue'),
                      const SizedBox(height: 12),
                      _buildRevenueChart(weeklyData),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildDesktopStatsGrid(double dailyRevenue, double dailyTrendPercent, bool dailyTrendUp, List<Map<String, dynamic>> weeklyData, int todayOrders, dynamic topPainter, dynamic topProduct) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _skeuomorphicStatCard(
                label: 'Daily Revenue',
                value: '₹${_formatCompact(dailyRevenue)}',
                valueNumber: dailyRevenue,
                icon: Icons.currency_rupee_rounded,
                color: AppColors.adminAccent,
                bg: AppColors.adminAccentLight,
                sparklineData: weeklyData,
                trendPercent: dailyTrendPercent,
                trendUp: dailyTrendUp,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _skeuomorphicStatCard(
                label: 'Orders Today',
                value: '$todayOrders',
                valueNumber: todayOrders.toDouble(),
                icon: Icons.shopping_bag_rounded,
                color: AppColors.textSlate,
                bg: AppColors.adminBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _skeuomorphicStatCard(
                label: 'Top Painter',
                value: topPainter != null
                    ? topPainter['name'] as String
                    : '—',
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFF059669),
                bg: const Color(0xFFECFDF5),
                sub: topPainter != null
                    ? '₹${_formatCompact(topPainter['amount'] as double)}'
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _skeuomorphicStatCard(
                label: 'Top Product',
                value: topProduct != null
                    ? topProduct['name'] as String
                    : '—',
                icon: Icons.star_rounded,
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFF5F3FF),
                sub: topProduct != null
                    ? '${topProduct['quantity']} units'
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatCompact(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  double _computeRevenueTrend(List<Map<String, dynamic>> data) {
    if (data.length < 2) return 0.0;
    final last = data.last['revenue'] as double;
    final prev = data[data.length - 2]['revenue'] as double;
    if (prev == 0) return last > 0 ? 100.0 : 0.0;
    return ((last - prev) / prev) * 100;
  }

  Widget _pill(IconData icon, String label,
      {double iconSize = 12, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 3,
            offset: const Offset(-1, -1),
          ),
          BoxShadow(
            color: const Color(0xFFD1CCC4).withOpacity(0.4),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: iconSize, color: color ?? AppColors.textSlateLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSlate,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textSlate,
        letterSpacing: -0.2,
      ),
    );
  }

  // ── SKEUOMORPHIC STAT CARD ─────────────────────────────────────────────
  Widget _skeuomorphicStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
    String? sub,
    double? valueNumber,
    List<Map<String, dynamic>>? sparklineData,
    double? trendPercent,
    bool trendUp = true,
    bool fullWidth = false,
  }) {
    final trendLabel = trendPercent != null
        ? '${trendUp ? '⭡' : '⭣'} ${trendPercent.abs().toStringAsFixed(0)}% vs Yesterday'
        : null;
    final points = sparklineData != null && sparklineData.isNotEmpty
        ? sparklineData.asMap().entries.map((e) {
            final index = e.key.toDouble();
            return FlSpot(index, (e.value['revenue'] as double));
          }).toList()
        : <FlSpot>[];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 3,
                        offset: const Offset(-1, -1),
                      ),
                      BoxShadow(
                        color: const Color(0xFFD1CCC4).withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                if (sub != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sub,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            valueNumber != null
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: valueNumber),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animated, child) {
                      final text = valueNumber % 1 == 0
                          ? animated.round().toString()
                          : _formatCompact(animated);
                      return Text(
                        label == 'Daily Revenue' ? '₹$text' : text,
                        style: GoogleFonts.inter(
                          fontSize: fullWidth ? 28 : 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSlate,
                          letterSpacing: -0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: fullWidth ? 20 : 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSlate,
                      height: 1.1,
                      letterSpacing: fullWidth ? -0.5 : -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlateLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: points,
                        isCurved: true,
                        dotData: FlDotData(show: false),
                        color:
                            trendUp ? AppColors.success : AppColors.error,
                        barWidth: 2.5,
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              (trendUp ? AppColors.success : AppColors.error)
                                  .withOpacity(0.10),
                        ),
                      ),
                    ],
                    minY: 0,
                  ),
                ),
              ),
            ],
            if (trendLabel != null) ...[
              const SizedBox(height: 10),
              _trendPill(trendLabel, positive: trendUp),
            ],
          ],
        ),
      ),
    );
  }

  Widget _trendPill(String label, {bool positive = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE6F8F0) : const Color(0xFFFEEDEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: positive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  // ── REVENUE CHART ─────────────────────────────────────────────────────────
  Widget _buildRevenueChart(List<Map<String, dynamic>> data) {
    final maxRevenue = data.fold(0.0,
        (max, d) => (d['revenue'] as double) > max ? d['revenue'] as double : max);
    final yMax = (maxRevenue > 0 ? maxRevenue * 1.3 : 10000).toDouble();

    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.85),
            blurRadius: 14,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color: const Color(0xFFD1CCC4).withOpacity(0.65),
            blurRadius: 14,
            offset: const Offset(6, 6),
          ),
        ],
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
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.adminAccent, Color(0xFFF59E0B)],
                  ),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data[i]['dayLabel'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlateLight,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '₹${_formatCompact(rod.toY)}',
                  GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
