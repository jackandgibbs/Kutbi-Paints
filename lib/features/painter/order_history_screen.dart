import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/custom_invoice_service.dart';
import '../../services/bill_export_service.dart';
import '../../core/utils/responsive.dart';

enum _OrderListType { active, deletedOrRejected, returned }

class OrderHistoryScreen extends ConsumerWidget {
  final String? initialTab;

  const OrderHistoryScreen({super.key, this.initialTab});

  int _getInitialIndex() {
    if (initialTab == 'deleted' || initialTab == 'rejected' || initialTab == '1') {
      return 1;
    }
    if (initialTab == 'returned' || initialTab == '2') {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final ds = ref.watch(dataServiceProvider);
    final allOrders = ds.getOrdersByPainter(user.id);

    bool isOrderDeleted(OrderModel o) => o.deletedByUser || o.deletedByAdmin || o.status == 'deleted';
    bool isOrderReturned(OrderModel o) => !isOrderDeleted(o) && (o.isReturned || ds.hasApprovedReturnForOrder(o.id) || o.status == 'returned');
    bool isOrderDeletedOrRejected(OrderModel o) => isOrderDeleted(o) || o.isRejected;

    // 1. Completed / In Progress orders: includes 'placed' (New), 'accepted', 'preparing', 'dispatched', 'delivered'
    const allowedActiveStatuses = {'placed', 'accepted', 'preparing', 'dispatched', 'delivered'};
    final inProgressOrCompletedOrders = allOrders.where((o) =>
        !isOrderDeleted(o) &&
        !o.isRejected &&
        !isOrderReturned(o) &&
        allowedActiveStatuses.contains(o.status)
    ).toList();

    // 2. Deleted / Rejected orders: deleted by user or admin, or cancelled/rejected
    final deletedOrRejectedOrders = allOrders.where((o) =>
        isOrderDeletedOrRejected(o)
    ).toList();

    // 3. Returned orders: non-deleted returned orders
    final returnedOrders = allOrders.where((o) =>
        isOrderReturned(o)
    ).toList();

    return DefaultTabController(
      initialIndex: _getInitialIndex(),
      length: 3,
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
          title: Text('My Orders',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: [
              Tab(text: 'Completed / In Progress (${inProgressOrCompletedOrders.length})'),
              Tab(text: 'Deleted / Rejected (${deletedOrRejectedOrders.length})'),
              Tab(text: 'Returned (${returnedOrders.length})'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: TabBarView(
              children: [
                _buildOrderList(context, ref, inProgressOrCompletedOrders, ds, listType: _OrderListType.active),
                _buildOrderList(context, ref, deletedOrRejectedOrders, ds, listType: _OrderListType.deletedOrRejected),
                _buildOrderList(context, ref, returnedOrders, ds, listType: _OrderListType.returned),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    WidgetRef ref,
    List<OrderModel> orders,
    DataService ds, {
    required _OrderListType listType,
  }) {
    final IconData emptyIcon;
    final String emptyTitle;
    final String emptySubtitle;

    switch (listType) {
      case _OrderListType.active:
        emptyIcon = Icons.receipt_long_rounded;
        emptyTitle = 'No active orders';
        emptySubtitle = 'Place your first order to get started!';
        break;
      case _OrderListType.deletedOrRejected:
        emptyIcon = Icons.delete_outline_rounded;
        emptyTitle = 'No deleted or rejected orders';
        emptySubtitle = 'Orders you delete or that get rejected will appear here';
        break;
      case _OrderListType.returned:
        emptyIcon = Icons.assignment_return_rounded;
        emptyTitle = 'No returned orders';
        emptySubtitle = 'Orders with approved returns will appear here';
        break;
    }

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
                    Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      emptyTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16, 
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptySubtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13, 
                        color: AppColors.textLight,
                      ),
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
                final isReturned = order.isReturned || ds.hasApprovedReturnForOrder(order.id);
                final effectiveStatus = isReturned ? 'returned' : (order.isRejected ? 'rejected' : order.displayStatus);
                final brandColor = AppColors.getBrandPrimary(order.brand);
                final statusColor = _getStatusColor(effectiveStatus);
                final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

                return GestureDetector(
                  onTap: () => context.push('/painter/order-detail/${order.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (order.siteLocation.startsWith('Invoice #'))
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        order.siteLocation,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (order.isRejected ? AppColors.error : statusColor).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                effectiveStatus == 'placed' ? 'NEW' : effectiveStatus.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: order.isRejected ? AppColors.error : statusColor,
                                ),
                              ),
                            ),
                            if (listType == _OrderListType.active) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey.shade400),
                                tooltip: 'Delete Order',
                                onPressed: () => _confirmDeleteOrder(context, ds, order.id),
                              ),
                            ],
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
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Text(
                                           item.productName.isNotEmpty
                                               ? '${item.productName} (${item.bucketSize} × ${item.quantity})'
                                               : '${item.colorCode} - ${item.colorName} (${item.bucketSize} × ${item.quantity})',
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                        // View Invoice Bill button for invoice-linked orders
                        if (order.siteLocation.startsWith('Invoice #')) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _viewInvoicePdf(context, ref, order),
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: Text(
                                order.status == 'returned' ? 'View Return Bill (PDF)' : 'View Invoice Bill (PDF)',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: order.status == 'returned' ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],

                        // Reorder button for delivered orders
                        if (order.status == 'delivered' && !order.deletedByUser && !isReturned) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/painter/order/${Uri.encodeComponent(order.brand)}?reorderOrderId=${order.id}'),
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: Text('Reorder',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandColor,
                                side: BorderSide(color: brandColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Returned order banner
                        if (isReturned && !order.deletedByUser) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_return_rounded, color: Color(0xFF7C3AED), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.paymentMethod == 'udhaari'
                                        ? 'Return Approved • Udhaari Waived (₹0 Due)'
                                        : 'Return Approved • Order Returned',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF7C3AED),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Deleted by User section with Restore action
                        if (order.deletedByUser) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.amber.shade800, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You deleted this order',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await ds.restoreOrderByUser(order.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Order restored to active list')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.restore_rounded, size: 16),
                                  label: Text('Restore',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Deleted by Admin banner
                        if ((order.deletedByAdmin || order.status == 'deleted') && !order.deletedByUser) ...[
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
                                const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
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
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(
                                  '/painter/order/${Uri.encodeComponent(order.brand)}?reorderOrderId=${order.id}'),
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: Text('Reorder',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Rejected by Admin banner
                        if (order.isRejected && !order.deletedByUser && !order.deletedByAdmin && order.status != 'deleted') ...[
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
                                const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This order was rejected or cancelled by admin',
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
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(
                                  '/painter/order/${Uri.encodeComponent(order.brand)}?reorderOrderId=${order.id}'),
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: Text('Reorder',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
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

  Future<void> _confirmDeleteOrder(BuildContext context, DataService ds, String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text('Delete Order', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this order? It will be moved to the Deleted / Rejected tab and can be restored at any time.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ds.deleteOrderByUser(orderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order moved to Deleted / Rejected'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => ds.restoreOrderByUser(orderId),
            ),
          ),
        );
      }
    }
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
      case 'returned':
        return const Color(0xFF7C3AED);
      case 'cancelled':
      case 'rejected':
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

  Future<void> _viewInvoicePdf(BuildContext context, WidgetRef ref, OrderModel order) async {
    try {
      final invoiceService = ref.read(customInvoiceServiceProvider);
      CustomInvoiceModel? inv = invoiceService.getByOrderId(order.id);
      inv ??= CustomInvoiceModel.fromOrder(order);

      final pdfBytes = await BillExportService.generateCustomInvoicePdf(inv);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${inv.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing invoice bill: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
