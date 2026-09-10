import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/haptic_service.dart';
import '../../models/return_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../shared/widgets/user_avatar.dart';

// ============================================================================
// AdminReturnsScreen — admin view of painters with active return requests
// ============================================================================
class AdminReturnsScreen extends ConsumerStatefulWidget {
  const AdminReturnsScreen({super.key});

  @override
  ConsumerState<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends ConsumerState<AdminReturnsScreen> {
  // Navigation & filtering state
  String? _selectedPainterId;
  String _viewMode = 'painters'; // 'painters' or 'all_requests'
  String _searchQuery = '';
  String _filterStatus = 'all';

  static const _tabs = [
    ('all', 'All'),
    ('requested', 'Pending'),
    ('approved', 'Approved'),
    ('pickup_scheduled', 'Pickup'),
    ('received', 'Received'),
    ('refund_processing', 'Processing'),
    ('refunded', 'Refunded'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final allReturns = ds.getAllReturnRequests();
    final counts = ds.getReturnStatusCounts();

    // Active returns are those not in a terminal state (refunded, rejected, cancelled)
    final activeReturns = allReturns.where((r) => !r.status.isTerminal).toList();

    // Group active returns by painter (userId)
    final Map<String, List<ReturnRequestModel>> activeReturnsByPainter = {};
    for (final r in activeReturns) {
      activeReturnsByPainter.putIfAbsent(r.userId, () => []).add(r);
    }

    // Build list of painters with active returns
    final List<({UserModel? user, String userId, List<ReturnRequestModel> requests})> painterDataList = [];
    for (final entry in activeReturnsByPainter.entries) {
      final user = ds.getUserById(entry.key);
      painterDataList.add((
        user: user,
        userId: entry.key,
        requests: entry.value,
      ));
    }

    // Sort painters by latest request timestamp (newest first)
    painterDataList.sort((a, b) {
      final aLatest = a.requests.map((r) => r.requestedAt).reduce((v, e) => e.isAfter(v) ? e : v);
      final bLatest = b.requests.map((r) => r.requestedAt).reduce((v, e) => e.isAfter(v) ? e : v);
      return bLatest.compareTo(aLatest);
    });

    return PopScope(
      canPop: _selectedPainterId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedPainterId != null) {
          setState(() => _selectedPainterId = null);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.adminCardBg,
        body: SafeArea(
          bottom: false,
          child: Container(
            color: AppColors.adminBg,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: _selectedPainterId != null
                    ? _buildPainterDetailView(ds, allReturns)
                    : _buildMainView(ds, allReturns, activeReturns, painterDataList, counts),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Main View: Painters / All Requests ──────────────────────────────────
  Widget _buildMainView(
    DataService ds,
    List<ReturnRequestModel> allReturns,
    List<ReturnRequestModel> activeReturns,
    List<({UserModel? user, String userId, List<ReturnRequestModel> requests})> painterDataList,
    Map<String, int> counts,
  ) {
    // Filter painters by search query
    final q = _searchQuery.trim().toLowerCase();
    final filteredPainters = q.isEmpty
        ? painterDataList
        : painterDataList.where((item) {
            final name = (item.user?.name ?? '').toLowerCase();
            final phone = (item.user?.phone ?? '').toLowerCase();
            return name.contains(q) || phone.contains(q);
          }).toList();

    return Column(
      children: [
        // ── Top Stats Row ──
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatChip(
                  label: 'Painters with Returns',
                  count: painterDataList.length,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.person_search_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Pending Action',
                  count: counts['requested'] ?? 0,
                  color: AppColors.warning,
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'In Progress',
                  count: (counts['approved'] ?? 0) +
                      (counts['pickup_scheduled'] ?? 0) +
                      (counts['picked_up'] ?? 0) +
                      (counts['received'] ?? 0) +
                      (counts['refund_processing'] ?? 0),
                  color: AppColors.info,
                  icon: Icons.sync_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Refunded',
                  count: counts['refunded'] ?? 0,
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
          ),
        ),

        // ── View Mode Selector & Search ──
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              // Segmented Tab Toggle
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          setState(() {
                            _viewMode = 'painters';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _viewMode == 'painters' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _viewMode == 'painters'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 16,
                                color: _viewMode == 'painters'
                                    ? AppColors.adminAccent
                                    : AppColors.textSlateLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active Painters (${painterDataList.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: _viewMode == 'painters'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _viewMode == 'painters'
                                      ? AppColors.textSlate
                                      : AppColors.textSlateLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          setState(() {
                            _viewMode = 'all_requests';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _viewMode == 'all_requests' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _viewMode == 'all_requests'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.list_alt_rounded,
                                size: 16,
                                color: _viewMode == 'all_requests'
                                    ? AppColors.adminAccent
                                    : AppColors.textSlateLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'All Requests (${allReturns.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: _viewMode == 'all_requests'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _viewMode == 'all_requests'
                                      ? AppColors.textSlate
                                      : AppColors.textSlateLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_viewMode == 'painters') ...[
                const SizedBox(height: 10),
                // Search field for painters
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: AppColors.textSlateLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSlate),
                          decoration: InputDecoration(
                            hintText: 'Search painter by name or phone...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.textSlateLight,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSlateLight),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                // Filter chips for All Requests view
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabs.map((tab) {
                      final tabKey = tab.$1;
                      final tabLabel = tab.$2;
                      final tabCount = tabKey == 'all'
                          ? allReturns.length
                          : (counts[tabKey] ?? 0);
                      final selected = _filterStatus == tabKey;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            tabCount > 0 ? '$tabLabel ($tabCount)' : tabLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? Colors.white : AppColors.textSlateLight,
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _filterStatus = tabKey),
                          selectedColor: AppColors.adminAccent,
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: selected ? AppColors.adminAccent : Colors.grey.shade300,
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Body List ──
        Expanded(
          child: _viewMode == 'painters'
              ? _buildPaintersList(filteredPainters, ds)
              : _buildAllRequestsList(allReturns, ds),
        ),
      ],
    );
  }

  // ─── Painters List View ──────────────────────────────────────────────────
  Widget _buildPaintersList(
    List<({UserModel? user, String userId, List<ReturnRequestModel> requests})> painters,
    DataService ds,
  ) {
    if (painters.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 32, 32, Responsive.isDesktop(context) ? 32 : 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 38,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No painters found for "$_searchQuery"'
                    : 'No Active Return Requests',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSlate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching with another name or phone number.'
                    : 'All painter return requests have been processed or none are active right now.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSlateLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final bottomPad = Responsive.isDesktop(context) ? 24.0 : 120.0;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      itemCount: painters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final item = painters[i];
        final user = item.user;
        final requests = item.requests;

        // Calculate pending & in-transit counts for this painter
        final pendingCount = requests.where((r) => r.status == ReturnStatus.requested).length;
        final inTransitCount = requests.where((r) =>
            r.status == ReturnStatus.approved ||
            r.status == ReturnStatus.pickupScheduled ||
            r.status == ReturnStatus.pickedUp ||
            r.status == ReturnStatus.received ||
            r.status == ReturnStatus.refundProcessing).length;

        // Total refund value estimated
        final totalRefund = requests.fold<double>(0.0, (sum, r) => sum + r.refundAmount);

        return GestureDetector(
          onTap: () {
            HapticService.light();
            setState(() {
              _selectedPainterId = item.userId;
              _filterStatus = 'all'; // reset status filter for painter detail
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.adminCardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.adminBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Avatar + Name + Active Count Chip
                Row(
                  children: [
                    UserAvatar(
                      imageUrl: user?.profileImageUrl,
                      name: user?.name ?? 'Painter',
                      size: 46,
                      backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.name ?? 'Painter #${item.userId.substring(0, 6)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSlate,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user != null && user.tier.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: user.isGold
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: user.isGold
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFCBD5E1),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    user.tier.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: user.isGold
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 12,
                                color: AppColors.textSlateLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user?.phone ?? 'No phone',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSlateLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Active badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pendingCount > 0
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                              : const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pendingCount > 0
                                ? Icons.pending_actions_rounded
                                : Icons.sync_rounded,
                            size: 13,
                            color: pendingCount > 0
                                ? const Color(0xFFB45309)
                                : const Color(0xFF0369A1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${requests.length} Active',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: pendingCount > 0
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Breakdown of requests and Action button
                Row(
                  children: [
                    // Status breakdown chips
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (pendingCount > 0)
                            _miniStatusPill(
                              label: '$pendingCount Pending',
                              color: AppColors.warning,
                            ),
                          if (inTransitCount > 0)
                            _miniStatusPill(
                              label: '$inTransitCount Processing',
                              color: AppColors.info,
                            ),
                          if (totalRefund > 0)
                            _miniStatusPill(
                              label: '₹${totalRefund.toStringAsFixed(0)}',
                              color: AppColors.success,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tap arrow
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Returns',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.adminAccent,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppColors.adminAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniStatusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Painter Return Requests Drill-Down View ─────────────────────────────
  Widget _buildPainterDetailView(DataService ds, List<ReturnRequestModel> allReturns) {
    final painter = ds.getUserById(_selectedPainterId!);
    final painterReturns = allReturns.where((r) => r.userId == _selectedPainterId).toList();

    // Filter by selected tab
    final filtered = _filterStatus == 'all'
        ? painterReturns
        : painterReturns.where((r) => r.status.value == _filterStatus).toList();

    return Column(
      children: [
        // ── Top Navigation Bar for Selected Painter ──
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  HapticService.light();
                  setState(() => _selectedPainterId = null);
                },
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSlate),
                tooltip: 'Back to Painters',
              ),
              UserAvatar(
                imageUrl: painter?.profileImageUrl,
                name: painter?.name ?? 'Painter',
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      painter?.name ?? 'Painter Returns',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSlate,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${painter?.phone ?? ''} • ${painterReturns.length} Return Request${painterReturns.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (painter?.phone != null && painter!.phone.isNotEmpty)
                IconButton(
                  onPressed: () => launchUrl(Uri.parse('tel:${painter.phone}')),
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF0EA5E9), size: 20),
                  tooltip: 'Call Painter',
                ),
            ],
          ),
        ),

        // ── Status Filter Chips for Painter's Returns ──
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((tab) {
                final tabKey = tab.$1;
                final tabLabel = tab.$2;
                final count = tabKey == 'all'
                    ? painterReturns.length
                    : painterReturns.where((r) => r.status.value == tabKey).length;
                final selected = _filterStatus == tabKey;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      count > 0 ? '$tabLabel ($count)' : tabLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? Colors.white : AppColors.textSlateLight,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterStatus = tabKey),
                    selectedColor: AppColors.adminAccent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: selected ? AppColors.adminAccent : Colors.grey.shade300,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Painter Returns List ──
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: Responsive.isDesktop(context) ? 0 : 100),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_return_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No returns in this status',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, Responsive.isDesktop(context) ? 24.0 : 120.0),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final ret = filtered[i];
                    return _AdminReturnCard(
                      returnRequest: ret,
                      ds: ds,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── All Requests Flat List View ─────────────────────────────────────────
  Widget _buildAllRequestsList(List<ReturnRequestModel> allReturns, DataService ds) {
    final filtered = _filterStatus == 'all'
        ? allReturns
        : allReturns.where((r) => r.status.value == _filterStatus).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: Responsive.isDesktop(context) ? 0 : 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_return_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _filterStatus == 'all' ? 'No return requests' : 'No returns in this status',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSlateLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, Responsive.isDesktop(context) ? 24.0 : 120.0),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final ret = filtered[i];
        return _AdminReturnCard(
          returnRequest: ret,
          ds: ds,
        );
      },
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textSlateLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Admin return card ────────────────────────────────────────────────────────

class _AdminReturnCard extends StatelessWidget {
  final ReturnRequestModel returnRequest;
  final DataService ds;

  const _AdminReturnCard({
    required this.returnRequest,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    final painter = ds.getUserById(returnRequest.userId);
    final order = ds.getOrderById(returnRequest.orderId);
    final statusColor = _statusColor(returnRequest.status);

    return GestureDetector(
      onTap: () {
        HapticService.light();
        context.push('/admin/return-detail/${returnRequest.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.adminCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.adminBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        returnRequest.displayId,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSlate,
                        ),
                      ),
                      if (painter != null)
                        Text(
                          painter.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                    ],
                  ),
                ),
                _AdminStatusBadge(status: returnRequest.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            // Order / date / amount
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 13, color: AppColors.textSlateLight),
                const SizedBox(width: 4),
                Text(
                  order != null
                      ? 'Order #${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length).toUpperCase()}'
                      : (returnRequest.orderId.length >= 8 ? returnRequest.orderId.substring(0, 8) : returnRequest.orderId),
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSlateLight),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(returnRequest.requestedAt),
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSlateLight),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Items summary
            if (returnRequest.items.isNotEmpty)
              Text(
                '${returnRequest.items.length} item(s): '
                '${returnRequest.items.map((i) => i.productName).join(', ')}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSlate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  returnRequest.reason,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSlateLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                if (returnRequest.refundAmount > 0)
                  Text(
                    '₹${returnRequest.refundAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ReturnStatus status) {
  switch (status) {
    case ReturnStatus.requested:
      return AppColors.warning;
    case ReturnStatus.approved:
    case ReturnStatus.pickupScheduled:
    case ReturnStatus.pickedUp:
    case ReturnStatus.received:
      return AppColors.info;
    case ReturnStatus.refundProcessing:
      return const Color(0xFF8B5CF6);
    case ReturnStatus.refunded:
      return AppColors.success;
    case ReturnStatus.rejected:
      return AppColors.error;
    case ReturnStatus.cancelled:
      return AppColors.textSlateLight;
  }
}

class _AdminStatusBadge extends StatelessWidget {
  final ReturnStatus status;
  final Color color;
  const _AdminStatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
