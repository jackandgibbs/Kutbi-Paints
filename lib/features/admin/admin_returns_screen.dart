import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/return_model.dart';
import '../../services/data_service.dart';

// ============================================================================
// AdminReturnsScreen — admin view of all return requests
// ============================================================================
class AdminReturnsScreen extends ConsumerStatefulWidget {
  const AdminReturnsScreen({super.key});

  @override
  ConsumerState<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends ConsumerState<AdminReturnsScreen> {
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
    final all = ds.getAllReturnRequests();
    final counts = ds.getReturnStatusCounts();

    final filtered = _filterStatus == 'all'
        ? all
        : all.where((r) => r.status.value == _filterStatus).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: Column(
      children: [
        // Stats row
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatChip(
                  label: 'Pending',
                  count: counts['requested'] ?? 0,
                  color: AppColors.warning,
                  icon: Icons.schedule_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Processing',
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
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Rejected',
                  count: counts['rejected'] ?? 0,
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                ),
              ],
            ),
          ),
        ),
        // Filter tabs
        Container(
          color: AppColors.adminCardBg,
          padding: const EdgeInsets.only(bottom: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tabs.map((tab) {
                final tabKey = tab.$1;
                final tabLabel = tab.$2;
                final tabCount = tabKey == 'all'
                    ? all.length
                    : (counts[tabKey] ?? 0);
                final selected = _filterStatus == tabKey;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      tabCount > 0 ? '$tabLabel ($tabCount)' : tabLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : AppColors.textSlateLight,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _filterStatus = tabKey),
                    selectedColor: AppColors.adminAccent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: selected
                          ? AppColors.adminAccent
                          : Colors.grey.shade300,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_return_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _filterStatus == 'all'
                ? 'No return requests'
                : 'No returns in this status',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSlateLight,
            ),
          ),
        ],
      ),
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
      onTap: () => context
          .push('/admin/return-detail/${returnRequest.id}'),
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
                _AdminStatusBadge(
                    status: returnRequest.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            // Order / date / amount
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 13, color: AppColors.textSlateLight),
                const SizedBox(width: 4),
                Text(
                  order != null
                      ? 'Order #${order.id.substring(0, 8).toUpperCase()}'
                      : returnRequest.orderId.substring(0, 8),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSlateLight),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy')
                      .format(returnRequest.requestedAt),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSlateLight),
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
