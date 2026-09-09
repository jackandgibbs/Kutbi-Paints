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
    final allPromotions = ds.getAllPromotions;

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

    // Discount fields
    String discountMode = 'none'; // 'none', 'manual', or promo id
    double manualFlatDiscount = 0;
    double manualPercentDiscount = 0;
    String manualDiscountName = '';
    
    final manualFlatCtrl = TextEditingController();
    final manualPercentCtrl = TextEditingController();
    final manualNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double calculatedTotal = editableItems.fold(0.0, (sum, item) => sum + ((item['quantity'] as num) * (item['rate'] as num)).toDouble());
          
          double finalDiscountAmt = 0;
          String? finalDiscountName;

          if (calculatedTotal > 0) {
            if (discountMode == 'manual') {
              finalDiscountAmt = manualFlatDiscount;
              if (finalDiscountAmt > calculatedTotal) finalDiscountAmt = calculatedTotal;
              finalDiscountName = manualDiscountName.isNotEmpty ? manualDiscountName : 'Discount';
            } else if (discountMode != 'none') {
              try {
                final promo = allPromotions.firstWhere((p) => p.id == discountMode);
                finalDiscountAmt = calculatedTotal * promo.discountPercent;
                if (finalDiscountAmt > calculatedTotal) finalDiscountAmt = calculatedTotal;
                finalDiscountName = promo.title;
              } catch (_) {}
            }
          } else {
            discountMode = 'none'; // Reset if rates are 0
          }

          double finalAmount = calculatedTotal - finalDiscountAmt;
          if (finalAmount < 0) finalAmount = 0;

          return AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text('Generate Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'ESTIMATE',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
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
                                        double newTotal = editableItems.fold(0.0, (sum, it) => sum + ((it['quantity'] as num) * (it['rate'] as num)).toDouble());
                                        if (discountMode == 'manual' && newTotal > 0) {
                                          manualPercentDiscount = (manualFlatDiscount / newTotal) * 100;
                                          manualPercentCtrl.text = manualPercentDiscount.toStringAsFixed(2);
                                        }
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
                    const SizedBox(height: 20),
                    Text('Discount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: discountMode,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'none', child: Text('No Discount')),
                        const DropdownMenuItem(value: 'manual', child: Text('Manual Discount')),
                        ...ds.getAllPromotions.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.title} (${(p.discountPercent * 100).toStringAsFixed(0)}% OFF) - ${p.brand}'),
                        )),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          discountMode = val ?? 'none';
                        });
                      },
                    ),
                    if (discountMode == 'manual') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: manualNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Discount Name (e.g. Diwali Offer)',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setModalState(() => manualDiscountName = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: manualFlatCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Flat (₹)',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  manualFlatDiscount = double.tryParse(val) ?? 0;
                                  if (manualFlatDiscount > calculatedTotal && calculatedTotal > 0) manualFlatDiscount = calculatedTotal;
                                  if (calculatedTotal > 0) {
                                    manualPercentDiscount = (manualFlatDiscount / calculatedTotal) * 100;
                                    manualPercentCtrl.text = manualPercentDiscount.toStringAsFixed(2);
                                  } else {
                                    manualPercentCtrl.text = '0';
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: manualPercentCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Percentage (%)',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  manualPercentDiscount = double.tryParse(val) ?? 0;
                                  if (manualPercentDiscount > 100) manualPercentDiscount = 100;
                                  manualFlatDiscount = (manualPercentDiscount / 100) * calculatedTotal;
                                  manualFlatCtrl.text = manualFlatDiscount.toStringAsFixed(2);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (calculatedTotal == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Discount will be applied once you enter a rate.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error)),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                              Text('₹ ${calculatedTotal.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (finalDiscountAmt > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Discount (${finalDiscountName ?? 'Discount'})', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error)),
                                Text('- ₹ ${finalDiscountAmt.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Final Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              Text(
                                '₹ ${finalAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final pdfBytes = await BillExportService.generateOrderBill(
                      order: order,
                      painterName: painter?.name ?? 'Customer',
                      painterPhone: painter?.phone ?? '',
                      customTotal: finalAmount,
                      items: editableItems.map((e) => {
                        ...e,
                        'amount': (e['quantity'] as num) * (e['rate'] as num),
                      }).toList(),
                      subtotal: calculatedTotal,
                      discountAmount: finalDiscountAmt,
                      discountName: finalDiscountName,
                    );

                    final fileName = 'bill_${order.id.substring(0,8)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                    final pdfUrl = await ds.uploadBillPdf(order.id, pdfBytes, fileName);

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
                      finalAmount,
                      customItems: updatedItems,
                      subtotal: calculatedTotal,
                      discountAmount: finalDiscountAmt,
                      discountName: finalDiscountName,
                    );

                    if (commissionAmount > 0) {
                      await ds.updateOrderCommission(order.id, commissionAmount);
                    }

                    NotificationService.showBillUploaded(
                      orderId: order.id,
                      brand: order.brand,
                      amount: finalAmount,
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

