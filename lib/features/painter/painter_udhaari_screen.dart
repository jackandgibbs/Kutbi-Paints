import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';

/// Painter's read-only view of their Udhaari (credit) orders.
/// Shows two tabs: Pending and Completed with total counts.
class PainterUdhaariScreen extends ConsumerWidget {
  const PainterUdhaariScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final allOrders = ds.getOrdersByPainter(user.id);
    final pendingUdhaari = allOrders.where((o) =>
      o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari' && !o.deletedByAdmin
    ).toList();
    final completedUdhaari = allOrders.where((o) =>
      o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari_completed' && !o.deletedByAdmin
    ).toList();

    final totalPendingAmount = pendingUdhaari.fold<double>(
      0, (sum, o) => sum + o.totalAmount + (o.udhaariInterestAmount ?? 0),
    );
    final totalCompletedAmount = completedUdhaari.fold<double>(
      0, (sum, o) => sum + o.totalAmount + (o.udhaariInterestAmount ?? 0),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0EDE8),
        body: Column(
          children: [
            // ── Floating Claymorphic Header ──
            Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16, right: 16, bottom: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                          color: AppColors.textPrimary,
                          splashRadius: 22,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'My Udhaari',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                  ),
                  // Clay TabBar
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E4DF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD1CCC4).withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        final tabController = DefaultTabController.of(context);
                        return TabBar(
                          controller: tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(text: 'Pending (${pendingUdhaari.length})'),
                            Tab(text: 'Paid (${completedUdhaari.length})'),
                          ],
                          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textSecondary,
                          splashBorderRadius: BorderRadius.circular(12),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),

            // Summary row (Updated Clay Style)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.85),
                    blurRadius: 14,
                    offset: const Offset(-6, -6),
                  ),
                  BoxShadow(
                    color: const Color(0xFFD1CCC4).withValues(alpha: 0.65),
                    blurRadius: 14,
                    offset: const Offset(6, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryColumn(
                      'Pending',
                      '₹${totalPendingAmount.toStringAsFixed(0)}',
                      pendingUdhaari.length,
                      Colors.red.shade600,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: _summaryColumn(
                      'Settled',
                      '₹${totalCompletedAmount.toStringAsFixed(0)}',
                      completedUdhaari.length,
                      const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return TabBarView(
                    controller: tabController,
                    children: [
                      _buildList(pendingUdhaari, isPending: true),
                      _buildList(completedUdhaari, isPending: false),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryColumn(String label, String amount, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '$count order${count != 1 ? 's' : ''}',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<OrderModel> orders, {required bool isPending}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPending ? Icons.receipt_long_rounded : Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending udhaari' : 'No completed udhaari',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: orders.length,
      itemBuilder: (context, index) => _UdhaariCard(order: orders[index], isPending: isPending),
    );
  }
}

class _UdhaariCard extends StatelessWidget {
  final OrderModel order;
  final bool isPending;

  const _UdhaariCard({required this.order, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final isToBeRevealed = order.status == 'to_be_revealed' || order.status == 'udhaari_no_bill';
    final totalDue = order.totalAmount + (order.udhaariInterestAmount ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(18),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isToBeRevealed)
                      Text(
                        'To be revealed',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFFFF9800),
                        ),
                      )
                    else ...[
                      Text(
                        '₹${totalDue.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isPending ? Colors.red.shade600 : const Color(0xFF059669),
                        ),
                      ),
                      if ((order.udhaariInterestAmount ?? 0) > 0)
                        Text(
                          'Incl. ₹${order.udhaariInterestAmount!.toStringAsFixed(0)} interest',
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Brand + date
            Row(
              children: [
                Icon(Icons.palette_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  order.brand,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  _formatDate(order.createdAt),
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Items
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        ProductImage(
                          imageUrl: item.productImageUrl,
                          productId: item.productId,
                          brand: order.brand,
                          size: 36,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${item.bucketSize} • x${item.quantity}',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Status badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isToBeRevealed
                    ? const Color(0xFFFF9800).withOpacity(0.1)
                    : isPending
                        ? Colors.orange.shade50
                        : const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isToBeRevealed
                        ? Icons.schedule_rounded
                        : isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                    size: 16,
                    color: isToBeRevealed
                        ? const Color(0xFFFF9800)
                        : isPending ? Colors.orange.shade700 : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isToBeRevealed ? 'To be revealed' : isPending ? 'Payment Pending' : 'Paid & Settled',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToBeRevealed
                          ? const Color(0xFFFF9800)
                          : isPending ? Colors.orange.shade700 : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}
