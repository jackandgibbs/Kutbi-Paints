import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../core/utils/responsive.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final ds = ref.watch(dataServiceProvider);
    final allOrders = ds.getOrdersByPainter(user.id);
    final activeOrders = allOrders.where((o) => !o.deletedByAdmin).toList();
    final deletedOrders = allOrders.where((o) => o.deletedByAdmin).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/painter');
              }
            },
            icon: const Icon(Icons.arrow_back_ios_rounded),
          ),
          title: Text('Order History',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Active (${activeOrders.length})'),
              Tab(text: 'Deleted (${deletedOrders.length})'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: TabBarView(
              children: [
                _buildOrderList(context, ref, activeOrders, ds, isDeleted: false),
                _buildOrderList(context, ref, deletedOrders, ds, isDeleted: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, WidgetRef ref, List orders, DataService ds, {required bool isDeleted}) {
    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: orders.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top - 48,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDeleted ? Icons.delete_outline_rounded : Icons.receipt_long_rounded,
                      size: 64, 
                      color: Colors.grey.shade300
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDeleted ? 'No deleted orders' : 'No orders yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16, 
                        color: AppColors.textSecondary
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDeleted 
                        ? 'Orders deleted by admin will appear here'
                        : 'Place your first order to get started!',
                      style: GoogleFonts.poppins(
                        fontSize: 13, 
                        color: AppColors.textLight
                      )
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, i) {
                final order = orders[i];
                final brandColor = AppColors.getBrandPrimary(order.brand);
                final statusColor = _getStatusColor(order.status);
                final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                    .format(order.createdAt);
  
                return GestureDetector(
                  onTap: () =>
                      context.push('/painter/order-detail/${order.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: brandColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.shopping_bag_rounded,
                                  color: brandColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.brand,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (order.isRejected ? AppColors.error : statusColor)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.displayStatus.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: order.isRejected ? AppColors.error : statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...order.items.take(2).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(item.colorHex),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.colorCode} - ${item.colorName} (${item.bucketSize} × ${item.quantity})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        if (item.shadeCode != null && item.shadeCode!.isNotEmpty)
                                          Text(
                                            'Shade: ${item.shadeCode}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: brandColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        if (order.items.length > 2)
                          Text(
                            '+${order.items.length - 2} more items',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textLight,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₹${order.totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: brandColor,
                              ),
                            ),
                          ],
                        ),
                        if (order.status == 'delivered' && !isDeleted) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/painter/order/${Uri.encodeComponent(order.brand)}'),
                              icon: const Icon(Icons.replay_rounded,
                                  size: 18),
                              label: Text('Reorder',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandColor,
                                side: BorderSide(color: brandColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (order.deletedByAdmin) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This order was deleted by admin',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_bill':
        return Colors.orange;
      case 'billed':
      case 'bill_sent':
        return Colors.indigo;
      case 'placed':
        return AppColors.info;
      case 'accepted':
        return AppColors.primary;
      case 'preparing':
        return AppColors.warning;
      case 'dispatched':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'deleted':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
