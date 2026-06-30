import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/clay_card.dart';
import '../../core/widgets/skeuomorphic_background.dart';
import '../../models/qr_code_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

/// Painter "Rewards Earned" screen.
///
/// Shows the painter's current total points and a chronological list of all
/// QR stickers they have scanned (each scan that contributed to the total).
/// When the admin runs *Save & Reset*, the painter's points return to 0 here
/// and the previous balance is moved to the *Rewards History* screen.
class PainterRewardsScreen extends ConsumerStatefulWidget {
  const PainterRewardsScreen({super.key});

  @override
  ConsumerState<PainterRewardsScreen> createState() =>
      _PainterRewardsScreenState();
}

class _PainterRewardsScreenState extends ConsumerState<PainterRewardsScreen> {
  Future<List<QRCodeModel>>? _scansFuture;
  String? _loadedFor; // painterId we last loaded for

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  Future<void> _reload() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final ds = ref.read(dataServiceProvider);
    setState(() {
      _loadedFor = user.id;
      _scansFuture = ds.fetchScannedQRsForPainter(user.id);
    });
    // Also refresh user record so total points stays in sync.
    try {
      await ds.refresh();
    } catch (_) {/* non-fatal */}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final ds = ref.watch(dataServiceProvider);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view rewards.')),
      );
    }

    // Lazy init if post-frame callback hasn't run yet.
    if (_scansFuture == null || _loadedFor != user.id) {
      _scansFuture = ds.fetchScannedQRsForPainter(user.id);
      _loadedFor = user.id;
    }

    // Always read live points from the data service so it reflects scans /
    // admin resets in real time.
    final liveUser = ds.users.firstWhere(
      (u) => u.id == user.id,
      orElse: () => user,
    );
    final totalPoints = liveUser.points;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SkeuomorphicBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            color: AppColors.primary,
            child: FutureBuilder<List<QRCodeModel>>(
              future: _scansFuture,
              builder: (context, snapshot) {
                final scannedQRs = snapshot.data ?? const <QRCodeModel>[];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(context),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _TotalPointsCard(points: totalPoints),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                size: 18, color: AppColors.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Scans',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (isLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            else
                              Text(
                                '${scannedQRs.length}',
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
                    if (isLoading && scannedQRs.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (scannedQRs.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyScansView(
                          onScan: () => context.push('/painter/scanner'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverList.separated(
                          itemCount: scannedQRs.length,
                          separatorBuilder: (_, idx) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) =>
                              _ScannedQRTile(qr: scannedQRs[i]),
                        ),
                      ),
                  ],
                );
              },
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
        'Rewards Earned',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          onPressed: _reload,
        ),
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
          onPressed: () => context.push('/painter/rewards/history'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ───────────────────────── Total Points Card ─────────────────────────
class _TotalPointsCard extends StatelessWidget {
  final int points;
  const _TotalPointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      surfaceColor: AppColors.clayPastelAmber,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.stars_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Points',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  points == 0
                      ? 'Scan a QR sticker to start earning'
                      : 'Keep scanning to unlock rewards',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Scanned QR tile ─────────────────────────
class _ScannedQRTile extends StatelessWidget {
  final QRCodeModel qr;
  const _ScannedQRTile({required this.qr});

  @override
  Widget build(BuildContext context) {
    final usedAt = qr.usedAt;
    final dateStr = usedAt != null
        ? '${_two(usedAt.day)}/${_two(usedAt.month)}/${usedAt.year}  '
            '${_two(usedAt.hour)}:${_two(usedAt.minute)}'
        : '—';

    return ClayCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      surfaceColor: Colors.white,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qr.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
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
                if (qr.message != null && qr.message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    qr.message!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${qr.points} pts',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

// ───────────────────────── Empty state ─────────────────────────
class _EmptyScansView extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyScansView({required this.onScan});

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
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 18),
            Text(
              'No scans yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan a Kutbi Paints QR sticker to start earning reward points.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                'Scan QR',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
