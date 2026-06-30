import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/clay_card.dart';
import '../../core/widgets/skeuomorphic_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

/// Painter-side history of monthly *Save & Reset* cycles run by the admin.
///
/// Each entry corresponds to a month the admin archived. The points shown
/// are the painter's balance at the moment the admin reset everyone to 0.
class PainterRewardsHistoryScreen extends ConsumerStatefulWidget {
  const PainterRewardsHistoryScreen({super.key});

  @override
  ConsumerState<PainterRewardsHistoryScreen> createState() =>
      _PainterRewardsHistoryScreenState();
}

class _PainterRewardsHistoryScreenState
    extends ConsumerState<PainterRewardsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(dataServiceProvider).refresh();
      } catch (_) {/* non-fatal */}
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final ds = ref.watch(dataServiceProvider);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view history.')),
      );
    }

    final history = ds.getPainterPointsHistory(user.id);
    final totalArchivedPoints =
        history.fold<int>(0, (sum, m) => sum + ((m['points'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SkeuomorphicBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ds.refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _SummaryCard(
                      months: history.length,
                      totalPoints: totalArchivedPoints,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded,
                            size: 18, color: AppColors.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Past Months',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${history.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (history.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistoryView(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, idx) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _HistoryTile(record: history[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Rewards History',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ───────────────────────── Summary Card ─────────────────────────
class _SummaryCard extends StatelessWidget {
  final int months;
  final int totalPoints;
  const _SummaryCard({required this.months, required this.totalPoints});

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      surfaceColor: AppColors.clayPastelBlue,
      child: Row(
        children: [
          Expanded(
            child: _stat(
              icon: Icons.calendar_month_rounded,
              label: 'Months',
              value: '$months',
              color: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: Colors.black.withValues(alpha: 0.06),
          ),
          Expanded(
            child: _stat(
              icon: Icons.stars_rounded,
              label: 'Lifetime Points',
              value: '$totalPoints',
              color: const Color(0xFFFFB300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── History Tile ─────────────────────────
class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final month = (record['month'] as String?) ?? '—';
    final points = (record['points'] as int?) ?? 0;
    final resetDate = DateTime.tryParse(record['reset_date'] as String? ?? '');

    final dateStr = resetDate != null
        ? 'Reset on ${_two(resetDate.day)}/${_two(resetDate.month)}/${resetDate.year}'
        : 'Reset date unavailable';

    return ClayCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      surfaceColor: Colors.white,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  month,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$points pts',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8A6100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

// ───────────────────────── Empty State ─────────────────────────
class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded,
                  color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 18),
            Text(
              'No history yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Once your points are archived at month-end, they will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
