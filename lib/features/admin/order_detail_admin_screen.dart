import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';
import '../../core/utils/app_utils.dart';

class OrderDetailAdminScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailAdminScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailAdminScreen> createState() => _OrderDetailAdminScreenState();
}

class _OrderDetailAdminScreenState extends ConsumerState<OrderDetailAdminScreen> {
  final _amountCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController(text: '0');
  String? _uploadedBillUrl;
  final bool _isUploading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final order = ds.getOrderById(widget.orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final brandColor = AppColors.getBrandPrimary(order.brand);
    // Find painter to get phone number
    final painter = ds.getUserById(order.painterId);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Manage Order #${order.id.substring(0, 8)}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                      Text(
                        painter?.name ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (order.status == 'udhaari_pending_approval' ? 'UDHAARI PENDING' : order.status).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ProductImage(
                        imageUrl: order.items.first.productImageUrl,
                        productId: order.items.first.productId,
                        brand: order.brand,
                        size: 32,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.brand,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // In real app, launch caller
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Calling Painter...')),
                            );
                          },
                          icon: const Icon(Icons.call_rounded, size: 18, color: AppColors.adminPrimary),
                          label: Text(
                            'Call Painter',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.adminPrimary),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminPrimary.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),



            // Delivery Details
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.adminPrimary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Address',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.siteLocation,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => AppUtils.copyAddressToClipboard(context, order.siteLocation),
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              color: AppColors.adminPrimary,
                              tooltip: 'Copy Address',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Order Timeline Update
            Text(
              'Update Status',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildAdminTimeline(context, order, brandColor, ref, ds),
            ),
            const SizedBox(height: 24),

            // Items List
            Text(
              'Order Items',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ...order.items.map((item) {
              final color = _hexToColor(item.colorHex);
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
                      size: 36,
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
                            item.bucketSize,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'x${item.quantity}',
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
            const SizedBox(height: 40),
            
            // Cancellation Section
            if (order.status != 'cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context, ref, order),
                  icon: const Icon(Icons.cancel_rounded, color: AppColors.error),
                  label: Text('Cancel Order', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
            if (order.status == 'cancelled' && order.paidAmount > 0 && !order.refundCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('Refund Needed: ₹${order.paidAmount}', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _processRefund(context, ref, order.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Mark Refund as Completed', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'udhaari_pending_approval': return AppColors.warning;
      case 'placed': return Colors.indigo;
      case 'accepted': return Colors.teal;
      case 'billed': return Colors.orange;
      case 'bill_sent': return Colors.orange;
      case 'paid': return Colors.green;
      case 'preparing': return Colors.blue;
      case 'dispatched': return Colors.purple;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildAdminTimeline(BuildContext context, OrderModel order, Color brandColor, WidgetRef ref, DataService ds) {
    // Simplified status flow
    final statusList = ['placed', 'accepted', 'preparing', 'dispatched', 'delivered'];
    
    // Helper to find index
    int currentIdx = statusList.indexOf(order.status);
    if (currentIdx == -1 && order.status == 'cancelled') return const Text('Order Cancelled');
    
    if (currentIdx == -1) {
      if (order.status == 'pending_bill' || order.status == 'bill_sent' || order.status == 'billed' || order.status == 'udhaari_pending_approval') {
        currentIdx = 0;
      } else if (order.isConfirmed) currentIdx = 1;
    }

    return Column(
      children: List.generate(statusList.length, (index) {
        final status = statusList[index];
        final isCompleted = index <= currentIdx;
        final isCurrent = index == currentIdx;
        final isNext = index == currentIdx + 1;
        final isLast = index == statusList.length - 1;

        String title;
        IconData icon;
        Color statusColor;

        switch (status) {
          case 'pending_bill': title = 'Bill Pending'; icon = Icons.receipt_long_rounded; statusColor = Colors.orange; break;
          case 'accepted': title = 'Order Accepted'; icon = Icons.check_circle_rounded; statusColor = const Color(0xFF10B981); break;
          case 'preparing': title = 'Preparing'; icon = Icons.inventory_2_rounded; statusColor = const Color(0xFFF59E0B); break;
          case 'dispatched': title = 'Dispatched for site'; icon = Icons.local_shipping_rounded; statusColor = const Color(0xFF8B5CF6); break;
          case 'delivered': title = 'Successfully Delivered'; icon = Icons.stars_rounded; statusColor = const Color(0xFF10B981); break;
          default: title = status; icon = Icons.circle; statusColor = Colors.grey;
        }

        bool canAdvance = isNext;
        if (status == 'pending_bill') canAdvance = false; // Handled by bill upload
        if (status == 'accepted') canAdvance = false; // Handled by bill upload

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted ? statusColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? statusColor : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon, 
                    size: 18, 
                    color: isCompleted ? Colors.white : Colors.grey.shade300
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: canAdvance ? 70 : 50,
                    color: isCompleted ? statusColor : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                        color: isCompleted ? AppColors.textPrimary : AppColors.textLight,
                      ),
                    ),
                    if (isCurrent)
                      Text(
                        'Current Status',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (canAdvance) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ds.updateOrderStatus(order.id, status);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order marked as $title'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            status == 'preparing' ? 'Start Preparing' : 'Mark as $title',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _finalizeAndApprove(OrderModel order, DataService ds) async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    final rate = double.tryParse(_interestRateCtrl.text) ?? 0;
    
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    if (_uploadedBillUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload the bill photo first')));
      return;
    }

    try {
      await ds.approveUdhaariAndBill(
        orderId: order.id,
        totalAmount: amt,
        billImageUrl: _uploadedBillUrl!,
        enableInterest: rate > 0,
        interestRate: rate,
        interestAmount: (amt * rate / 100), // Simple interest for demonstration
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Finalized Successfully! Painter can now see it.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel this order?\n\nIf money was paid, a refund status will be required.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              ref.read(dataServiceProvider).updateOrderStatus(order.id, 'cancelled');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  Future<void> _processRefund(BuildContext context, WidgetRef ref, String orderId) async {
    try {
      await ref.read(dataServiceProvider).processRefund(orderId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund Processed Successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
