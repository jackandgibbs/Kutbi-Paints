import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/return_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

// ============================================================================
// MyReturnsScreen — painter sees all their return requests
// ============================================================================
class MyReturnsScreen extends ConsumerStatefulWidget {
  const MyReturnsScreen({super.key});

  @override
  ConsumerState<MyReturnsScreen> createState() => _MyReturnsScreenState();
}

class _MyReturnsScreenState extends ConsumerState<MyReturnsScreen> {
  ReturnStatus? _filterStatus; // null = show all

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final all = ds.getReturnRequestsByPainter(user.id);
    final filtered = _filterStatus == null
        ? all
        : all.where((r) => r.status == _filterStatus).toList();

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/painter');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'My Returns',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/painter');
              }
            },
          ),
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    count: all.length,
                    selected: _filterStatus == null,
                    onTap: () => setState(() => _filterStatus = null),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  ..._visibleFilters(all).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: entry.key.label,
                        count: entry.value,
                        selected: _filterStatus == entry.key,
                        onTap: () =>
                            setState(() => _filterStatus = entry.key),
                        color: _statusColor(entry.key),
                      ),
                    );
                  }),
                ],
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
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) =>
                        _ReturnCard(returnRequest: filtered[i]),
                  ),
          ),
        ],
      ),
    ),
    ),
    ),
  );
}

  List<MapEntry<ReturnStatus, int>> _visibleFilters(
      List<ReturnRequestModel> all) {
    final counts = <ReturnStatus, int>{};
    for (final r in all) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    return counts.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_return_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _filterStatus == null
                  ? 'No return requests yet'
                  : 'No ${_filterStatus!.label.toLowerCase()} returns',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Return requests will appear here after submission.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
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
      return AppColors.info;
    case ReturnStatus.pickupScheduled:
      return AppColors.info;
    case ReturnStatus.pickedUp:
      return AppColors.info;
    case ReturnStatus.received:
      return AppColors.info;
    case ReturnStatus.refundProcessing:
      return const Color(0xFF8B5CF6);
    case ReturnStatus.refunded:
      return AppColors.success;
    case ReturnStatus.rejected:
      return AppColors.error;
    case ReturnStatus.cancelled:
      return AppColors.textLight;
  }
}

// ─── Return card ──────────────────────────────────────────────────────────────

class _ReturnCard extends ConsumerWidget {
  final ReturnRequestModel returnRequest;
  const _ReturnCard({required this.returnRequest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.read(dataServiceProvider);
    final order = ds.getOrderById(returnRequest.orderId);
    final statusColor = _statusColor(returnRequest.status);

    return GestureDetector(
      onTap: () =>
          context.push('/painter/return-tracking/${returnRequest.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    returnRequest.displayId,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (returnRequest.billUrl != null && returnRequest.billUrl!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text(
                          'Bill Ready',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _StatusBadge(
                    status: returnRequest.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 4),
            if (order != null)
              Text(
                'Order #${order.id.substring(0, 8).toUpperCase()} · ${order.brand}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 10),
            // Items summary
            if (returnRequest.items.isNotEmpty) ...[
              Text(
                returnRequest.items.map((i) => i.productName).join(', '),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy')
                        .format(returnRequest.requestedAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (returnRequest.refundAmount > 0)
                  Text(
                    'Refund: ₹${returnRequest.refundAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ReturnStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
