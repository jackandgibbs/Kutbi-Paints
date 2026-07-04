import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/order_model.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';
import '../../services/bill_export_service.dart';

class AdminPendingBillsScreen extends ConsumerStatefulWidget {
  const AdminPendingBillsScreen({super.key});

  @override
  ConsumerState<AdminPendingBillsScreen> createState() => _AdminPendingBillsScreenState();
}

class _AdminPendingBillsScreenState extends ConsumerState<AdminPendingBillsScreen> {
  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final pendingBills = ds.getOrdersForBilling();

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            children: [
              // Header
              Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16, right: 16, bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Pending Bills',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Generate or upload bills',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.adminAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.adminAccent),
                            const SizedBox(width: 6),
                            Text(
                              '${pendingBills.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.adminAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: pendingBills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text('All caught up!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Text('No pending bills to process.', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendingBills.length,
                        itemBuilder: (context, index) {
                          final order = pendingBills[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order #${order.id.substring(0, 8)}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        order.brand,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.adminAccent),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Painter: ${ds.getUserById(order.painterId)?.name ?? 'Unknown'}',
                                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Amount: ₹${order.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showBillingDialog(order),
                                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                                          label: Text('Generate Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.adminAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _confirmDeleteOrder(order),
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        color: AppColors.error,
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBillingDialog(OrderModel order) async {
    final ds = ref.read(dataServiceProvider);
    final painter = ds.getUserById(order.painterId);

    // Local copy of items for editing rates
    final editableItems = order.items.map((item) => {
      'name': item.productName,
      'bucketSize': item.bucketSize,
      'quantity': item.quantity,
      'rate': (item.unitPrice > 0 ? item.unitPrice : 0).toDouble(),
    }).toList();

    // Commission field
    double commissionAmount = 0;
    final commissionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double calculatedTotal = editableItems.fold(0.0, (sum, item) => sum + ((item['quantity'] as num) * (item['rate'] as num)).toDouble());

          return AlertDialog(
            title: Text('Create Official Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.adminAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.adminAccent.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.adminAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Billing for: ${order.painterName ?? 'Customer'}',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.adminAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Enter rates for each item:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: editableItems.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final item = editableItems[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Qty: ${item['quantity']}',
                                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item['bucketSize']}×${item['quantity']}',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: (item['rate'] as num).toDouble() > 0 ? item['rate'].toString() : '',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: 'Rate',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                    onChanged: (val) {
                                      setModalState(() {
                                        editableItems[i]['rate'] = double.tryParse(val) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        Text(
                          '₹ ${calculatedTotal.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Commission field (optional)
                  TextFormField(
                    controller: commissionCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Painter Commission (optional)',
                      prefixText: '₹ ',
                      hintText: '0',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                      ),
                      helperText: 'Leave blank or 0 for no commission',
                      helperStyle: GoogleFonts.poppins(fontSize: 11),
                    ),
                    onChanged: (v) {
                      setModalState(() {
                        commissionAmount = double.tryParse(v) ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // 1. Generate PDF
                    final pdfBytes = await BillExportService.generateOrderBill(
                      order: order,
                      painterName: painter?.name ?? 'Customer',
                      painterPhone: painter?.phone ?? '',
                      customTotal: calculatedTotal,
                      items: editableItems.map((e) => {
                        ...e,
                        'amount': (e['quantity'] as num) * (e['rate'] as num),
                      }).toList(),
                    );

                    // 2. Upload PDF to Supabase Storage
                    final fileName = 'bill_${order.id.substring(0,8)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                    final pdfUrl = await ds.uploadBillPdf(order.id, pdfBytes, fileName);

                    // 3. Update Order in DB with PDF URL
                    final List<OrderItemModel> updatedItems = order.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final rate = (editableItems[i]['rate'] as num).toDouble();
                      return item.copyWith(
                        unitPrice: rate,
                        totalPrice: rate * item.quantity,
                      );
                    }).toList();

                    await ds.uploadBill(
                      order.id,
                      pdfUrl,
                      calculatedTotal,
                      customItems: updatedItems,
                    );

                    // 3b. Save commission if > 0
                    if (commissionAmount > 0) {
                      await ds.updateOrderCommission(order.id, commissionAmount);
                    }

                    // 4. Notify User
                    NotificationService.showBillUploaded(
                      orderId: order.id,
                      brand: order.brand,
                      amount: calculatedTotal,
                    );

                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bill generated and uploaded!'), backgroundColor: AppColors.success),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminAccent, foregroundColor: Colors.white),
                child: const Text('Generate & Notify'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _confirmDeleteOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Order?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will mark the order as deleted. The painter will see it in their "Deleted Orders" tab.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dataServiceProvider).deleteOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
