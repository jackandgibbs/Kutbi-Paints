import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/data_service.dart';
import '../../services/custom_invoice_service.dart';
import '../../services/bill_export_service.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final order = ds.getOrderById(orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final brandColor = AppColors.getBrandPrimary(order.brand);
    final isReturned = order.isReturned || ds.hasApprovedReturnForOrder(order.id);
    final effectiveStatus = isReturned ? 'returned' : order.displayStatus;
    final isBilled = order.status == 'billed' || order.status == 'bill_sent' || order.status == 'accepted';
    final isPaid = order.paymentStatus == 'udhaari';
    final isUdhaariRequested = order.status == 'udhaari_requested';
    final linkedInvoice = ref.watch(customInvoiceServiceProvider).getByOrderId(order.id);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Order Notes',
            onPressed: () => context.push('/order/${order.id}/chat'),
          ),
          if (!order.deletedByUser && !order.deletedByAdmin && order.status != 'deleted')
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Delete Order',
              onPressed: () => _showDeleteConfirmation(context, ref, order.id),
            )
          else if (order.deletedByUser)
            IconButton(
              icon: const Icon(Icons.restore_rounded, color: AppColors.primary),
              tooltip: 'Restore Order',
              onPressed: () async {
                await ds.restoreOrderByUser(order.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order restored to active list')),
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [brandColor, brandColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          effectiveStatus.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.isToBeRevealed 
                        ? 'To be revealed'
                        : (order.totalAmount > 0 || isPaid) 
                            ? (isReturned && order.paymentMethod == 'udhaari'
                                ? '₹0 (Returned)'
                                : '₹${order.totalAmount.toStringAsFixed(0)}')
                            : (isUdhaariRequested ? 'Under Review' : 'Waiting for Bill'),
                    style: GoogleFonts.poppins(
                      fontSize: order.isToBeRevealed ? 22 : 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Generated Invoice Banner (if created from Generate Invoice)
            if (order.siteLocation.startsWith('Invoice #') || linkedInvoice != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0284C7).withValues(alpha: 0.12),
                      const Color(0xFF0284C7).withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.status == 'returned' ? 'Return Bill / Credit Note' : 'Generated Purchase Bill',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            order.siteLocation.startsWith('Invoice #')
                                ? order.siteLocation
                                : (linkedInvoice?.invoiceNumber != null
                                    ? 'Invoice #${linkedInvoice!.invoiceNumber}'
                                    : 'Official Store Bill'),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final inv = linkedInvoice ?? CustomInvoiceModel.fromOrder(order);
                          final pdfBytes = await BillExportService.generateCustomInvoicePdf(inv);
                          await Printing.layoutPdf(
                            onLayout: (format) async => pdfBytes,
                            name: '${inv.invoiceNumber}.pdf',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error viewing invoice: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('View Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: order.status == 'returned' ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Deleted by user banner
            if (order.deletedByUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.amber.shade800, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Deleted',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          Text(
                            'You moved this order to Deleted / Rejected. You can restore it anytime.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await ds.restoreOrderByUser(order.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order restored to active list')),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: Text('Restore', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Deleted by admin banner
            if ((order.deletedByAdmin || order.status == 'deleted') && !order.deletedByUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Deleted',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            'This order was deleted by admin.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.error.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rejected / Cancelled by admin banner
            if (order.isRejected && !order.deletedByUser && !order.deletedByAdmin && order.status != 'deleted') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Cancelled / Rejected',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            'This order was cancelled or rejected by admin.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.error.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Payment Details / Udhaari info
            if (order.totalAmount > 0 && order.status != 'pending_bill' && order.status != 'bill_sent' && order.paymentMethod != 'pending') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('Payment Method', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                         Text(order.paymentMethod.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                       ],
                     ),
                     const Divider(height: 24),
                     if (order.discountAmount > 0) ...[
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Subtotal', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                           Text('₹${order.subtotal.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                         ],
                       ),
                       const SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Discount (${order.discountName ?? "Offer"})', style: GoogleFonts.poppins(color: AppColors.error)),
                           Text('-₹${order.discountAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppColors.error)),
                         ],
                       ),
                       const Divider(height: 24),
                     ],
                     if (order.paymentMethod == 'udhaari' && order.udhaariInterestEnabled) ...[
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Base Total', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                           Text('₹${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                         ],
                       ),
                       const SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Interest (${order.udhaariInterestRate}% p.a.)', style: GoogleFonts.poppins(color: Colors.red)),
                           Text('+₹${order.udhaariInterestAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.red)),
                         ],
                       ),
                       const Divider(height: 24),
                     ],
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('Total Payable', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                         Text('₹${(order.totalAmount + order.udhaariInterestAmount).toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                       ],
                     ),
                     if (order.paymentMethod != 'udhaari') ...[
                       const SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Amount Paid', style: GoogleFonts.poppins(color: AppColors.success)),
                           Text('₹${order.paidAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.success)),
                         ],
                       ),
                       const SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Remaining Balance', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                           Text('₹${order.remainingAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                         ],
                       ),
                     ],
                     if (isReturned) ...[
                       const Divider(height: 24),
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                         ),
                         child: Row(
                           children: [
                             const Icon(Icons.assignment_return_rounded, color: Color(0xFF7C3AED), size: 20),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 order.paymentMethod == 'udhaari'
                                     ? 'Order Returned — Udhaari Waived (No payment needed)'
                                     : 'Order Returned — Return Approved',
                                 style: GoogleFonts.poppins(
                                   fontSize: 12,
                                   fontWeight: FontWeight.w600,
                                   color: const Color(0xFF7C3AED),
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
              const SizedBox(height: 24),
            ],

            // Removed payment selection button as it's handled in Bills screen or automatically

            // Order Timeline
            Text(
              'Order Status',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeline(order, brandColor),
            const SizedBox(height: 24),

            // Shipping Details
            Text(
              'Delivery Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_rounded, color: brandColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Site Location',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.siteLocation,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Order Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${order.items.length} Items',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...order.items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ProductImage(
                      imageUrl: item.productImageUrl,
                      productId: item.productId,
                      brand: order.brand,
                      size: 40,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.shadeCode != null && item.shadeCode!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SHADE: ${item.shadeCode}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          Text(
                            '${item.bucketSize} • x${item.quantity}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPaid || isBilled)
                       Text(
                         '₹${item.totalPrice > 0 ? item.totalPrice.toStringAsFixed(0) : (order.totalAmount > 0 ? "Included" : "-")}',
                         style: GoogleFonts.poppins(
                           fontSize: 14,
                           fontWeight: FontWeight.w600,
                           color: AppColors.textPrimary,
                         ),
                       ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Delete Button
            // Delete Order Button for active orders
            if (!order.deletedByUser && !order.deletedByAdmin && order.status != 'deleted')
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmation(context, ref, order.id),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    label: Text(
                      'Delete Order',
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            // ─── Return Order Button (delivered or returned orders) ───────
            if (order.status == 'delivered' || isReturned) ...[     
              const SizedBox(height: 8),
              _ReturnOrderSection(order: order, ds: ds),
            ],
          ],
        ),
      ),
      ),
    ),
  );
}

  Widget _buildTimeline(OrderModel order, Color brandColor, {bool isReturned = false}) {
    if (isReturned) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_return_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Returned',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  Text(
                    order.paymentMethod == 'udhaari'
                        ? 'Return approved by admin • Udhaari waived (₹0 Due)'
                        : 'Return request approved by admin',
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

    // If order is rejected or cancelled, show cancelled status
    if (order.isRejected) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Cancelled',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    'This order was cancelled by admin',
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

    // Simplified flow: pending_bill → accepted → preparing → dispatched → delivered
    final statusList = ['pending_bill', 'accepted', 'preparing', 'dispatched', 'delivered'];
    
    int currentIdx = statusList.indexOf(order.status);
    if (currentIdx == -1 && order.status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Cancelled',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    'This order was cancelled',
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
    
    // Fallback for legacy statuses
    if (currentIdx == -1) {
      if (order.status == 'bill_sent' || order.status == 'billed' || order.status == 'udhaari_requested') {
        currentIdx = 0;
      } else if (order.status == 'placed' || order.status == 'udhaari_pending_approval') {
        currentIdx = 1; // 'placed'/'udhaari_pending_approval' maps to 'accepted'
      } else if (order.isConfirmed) {
        currentIdx = 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(statusList.length, (index) {
          final status = statusList[index];
          final isCompleted = index <= currentIdx;
          final isCurrent = index == currentIdx;
          final isLast = index == statusList.length - 1;

          String title;
          String subtitle;
          IconData icon;

          switch (status) {
            case 'pending_bill':
              title = 'Order Placed';
              subtitle = 'Waiting for Admin to generate bill';
              icon = Icons.receipt_long_rounded;
              break;
            case 'accepted':
              title = 'Order Accepted';
              subtitle = 'Bill uploaded. Your order is confirmed.';
              icon = Icons.check_circle_rounded;
              break;
            case 'preparing':
              title = 'Preparing';
              subtitle = 'Items are being packed';
              icon = Icons.inventory_2_rounded;
              break;
            case 'dispatched':
              title = 'Dispatched';
              subtitle = 'Your order is on the way';
              icon = Icons.local_shipping_rounded;
              break;
            case 'delivered':
              title = 'Delivered';
              subtitle = 'Successfully delivered to site';
              icon = Icons.home_work_rounded;
              break;
            default:
              title = status;
              subtitle = '';
              icon = Icons.circle;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                   Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted ? brandColor : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isCompleted ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted ? brandColor : Colors.grey.shade200,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // Removed legacy payment confirmation methods

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(dataServiceProvider).deleteOrderByUser(orderId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order moved to Deleted / Rejected')),
                );
                context.pop();
              }
            }, 
            child: const Text('Yes, Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Return Order Section ────────────────────────────────────────────────────

class _ReturnOrderSection extends ConsumerWidget {
  final OrderModel order;
  final DataService ds;

  const _ReturnOrderSection({required this.order, required this.ds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEligible = ds.isOrderReturnEligible(order);
    final daysLeft = ds.returnWindowDaysRemaining(order);
    final existingReturns = ds.getReturnRequestsForOrder(order.id);
    final activeReturn = existingReturns.isEmpty
        ? null
        : existingReturns.first; // most recent

    // Show existing active return status instead of button
    if (activeReturn != null && !activeReturn.status.isTerminal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GestureDetector(
          onTap: () =>
              context.push('/painter/return-tracking/${activeReturn.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return_rounded,
                    color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return ${activeReturn.status.label}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                      Text(
                        activeReturn.displayId,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.info, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    if (!isEligible && daysLeft < 0) {
      // Window expired
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_off_outlined,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                'Return window expired (7 days)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isEligible) return const SizedBox.shrink();

    // Eligible — show button
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (daysLeft <= 3 && daysLeft >= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Return window closes in $daysLeft day(s)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('/painter/return-request/${order.id}'),
              icon: const Icon(Icons.assignment_return_rounded),
              label: Text(
                'Return Order',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

