import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/responsive_center.dart';
import '../../models/return_model.dart';
import '../../models/order_model.dart';
import '../../services/data_service.dart';
import '../../services/bill_export_service.dart';

// ============================================================================
// ReturnDetailAdminScreen — admin manages a single return request
// ============================================================================
class ReturnDetailAdminScreen extends ConsumerStatefulWidget {
  final String returnId;
  const ReturnDetailAdminScreen({super.key, required this.returnId});

  @override
  ConsumerState<ReturnDetailAdminScreen> createState() =>
      _ReturnDetailAdminScreenState();
}

class _ReturnDetailAdminScreenState
    extends ConsumerState<ReturnDetailAdminScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataServiceProvider).fetchReturnItemsIfEmpty(widget.returnId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final returnRequest = ds.getReturnRequestById(widget.returnId);

    if (returnRequest == null) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        appBar: AppBar(title: const Text('Return Detail')),
        body: const Center(child: Text('Return request not found.')),
      );
    }

    final painter = ds.getUserById(returnRequest.userId);
    final order = ds.getOrderById(returnRequest.orderId);

    final displayItems = returnRequest.items.isNotEmpty
        ? returnRequest.items
        : (order != null
            ? order.items
                .asMap()
                .entries
                .map((entry) => ReturnRequestItemModel(
                      id: '${returnRequest.id}_${entry.key}',
                      returnRequestId: returnRequest.id,
                      orderId: returnRequest.orderId,
                      itemIndex: entry.key,
                      productId: entry.value.productId,
                      productName: entry.value.productName,
                      bucketSize: entry.value.bucketSize,
                      unitPrice: entry.value.unitPrice,
                      quantity: entry.value.quantity,
                      condition: 'returned',
                      createdAt: returnRequest.requestedAt,
                      updatedAt: returnRequest.requestedAt,
                    ))
                .toList()
            : <ReturnRequestItemModel>[]);

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      appBar: AppBar(
        backgroundColor: AppColors.adminCardBg,
        foregroundColor: AppColors.textSlate,
        elevation: 0,
        centerTitle: true,
        title: Text(
          returnRequest.displayId,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Delete Return Bill',
            onPressed: () => _confirmDelete(context, ds, returnRequest),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: Responsive.contentMaxWidth(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _StatusBanner(status: returnRequest.status),
            const SizedBox(height: 16),

            // Customer & order info
            _InfoCard(
              title: 'Customer & Order',
              children: [
                _row('Return ID', returnRequest.displayId),
                _row('Customer', painter?.name ?? 'Unknown'),
                _row('Phone', painter?.phone ?? '-'),
                if (order != null)
                  _row('Order', '#${order.id.substring(0, 8).toUpperCase()}'),
                if (order != null) _row('Brand', order.brand),
                _row(
                  'Requested',
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(returnRequest.requestedAt),
                ),
                _row('Reason', returnRequest.reason),
                if (returnRequest.description != null &&
                    returnRequest.description!.isNotEmpty)
                  _row('Description', returnRequest.description!),
              ],
            ),
            const SizedBox(height: 14),

            // Items
            if (displayItems.isNotEmpty) ...[
              _InfoCard(
                title: 'Return Items',
                children: displayItems.map((item) {
                  final prodName = item.productName.trim().isNotEmpty
                      ? item.productName
                      : (order != null && item.itemIndex < order.items.length
                          ? order.items[item.itemIndex].productName
                          : 'Paint Product');
                  final bSize = item.bucketSize.trim().isNotEmpty
                      ? item.bucketSize
                      : (order != null && item.itemIndex < order.items.length
                          ? order.items[item.itemIndex].bucketSize
                          : '1L');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                prodName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSlate,
                                ),
                              ),
                            ),
                            Text(
                              item.unitPrice > 0
                                  ? '₹${item.totalPrice.toStringAsFixed(0)}'
                                  : '-',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSlate,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$bSize · ${item.colorName ?? ""} · '
                          'Qty: ${item.quantity} · '
                          '₹${item.unitPrice.toStringAsFixed(0)}/unit',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                        Text(
                          'Condition: ${item.condition}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Refund amount
            if (returnRequest.refundAmount > 0 ||
                returnRequest.status == ReturnStatus.refundProcessing ||
                returnRequest.status == ReturnStatus.refunded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.08),
                      AppColors.success.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.success, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refund Amount',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                        Text(
                          returnRequest.refundAmount > 0
                              ? '₹${returnRequest.refundAmount.toStringAsFixed(0)}'
                              : '₹${returnRequest.computedRefundAmount.toStringAsFixed(0)} (estimated)',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Admin note
            if (returnRequest.cleanAdminNote != null &&
                returnRequest.cleanAdminNote!.isNotEmpty) ...[
              _InfoCard(
                title: returnRequest.status == ReturnStatus.rejected
                    ? 'Rejection Reason'
                    : 'Admin Note',
                children: [
                  Text(
                    returnRequest.cleanAdminNote!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSlate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Return Bill Card if bill is already generated
            if (returnRequest.billUrl != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Return Bill / Credit Note',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                              Text(
                                'Visible on customer panel',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSlateLight),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${returnRequest.refundAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showReturnBillPreview(returnRequest.billUrl!),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: Text('View Return Bill',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons based on status
            if (!returnRequest.status.isTerminal ||
                (returnRequest.status == ReturnStatus.refunded && returnRequest.billUrl != null))
              _ActionSection(
                returnRequest: returnRequest,
                isProcessing: _isProcessing,
                onAction: _handleAction,
                onGenerateBill: () => _showGenerateReturnBillDialog(context, returnRequest),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _handleAction(
    String action, {
    String? note,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final ds = ref.read(dataServiceProvider);

    try {
      switch (action) {
        case 'approve':
          await ds.approveReturn(widget.returnId, adminNote: note);
          break;
        case 'reject':
          await ds.rejectReturn(widget.returnId,
              reason: note ?? 'Return rejected by admin.');
          break;
        case 'pickup_scheduled':
          await ds.advanceReturnStatus(
              widget.returnId, ReturnStatus.pickupScheduled,
              adminNote: note);
          break;
        case 'picked_up':
          await ds.advanceReturnStatus(
              widget.returnId, ReturnStatus.pickedUp,
              adminNote: note);
          break;
        case 'received':
          await ds.advanceReturnStatus(
              widget.returnId, ReturnStatus.received,
              adminNote: note);
          break;
        case 'refund_processing':
          await ds.advanceReturnStatus(
              widget.returnId, ReturnStatus.refundProcessing,
              adminNote: note);
          break;
        case 'refunded':
          await ds.advanceReturnStatus(
              widget.returnId, ReturnStatus.refunded,
              adminNote: note);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return status updated.'),
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showReturnBillPreview(String url) async {
    try {
      final uri = Uri.parse(url);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        await Printing.layoutPdf(
          onLayout: (_) => res.bodyBytes,
          name: 'Return_Bill.pdf',
        );
        return;
      }
    } catch (_) {}
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open bill: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showGenerateReturnBillDialog(
    BuildContext context,
    ReturnRequestModel returnRequest,
  ) async {
    final ds = ref.read(dataServiceProvider);
    final order = ds.getOrderById(returnRequest.orderId);
    final painter = ds.getUserById(returnRequest.userId);

    // If items are empty in memory, attempt fetch from Supabase
    if (returnRequest.items.isEmpty) {
      await ds.fetchReturnItemsIfEmpty(returnRequest.id);
    }
    final activeRequest = ds.getReturnRequestById(returnRequest.id) ?? returnRequest;

    final List<Map<String, dynamic>> editableItems = [];
    if (activeRequest.items.isNotEmpty) {
      for (final item in activeRequest.items) {
        String name = item.productName.trim();
        String size = item.bucketSize.trim();
        double rate = item.unitPrice > 0 ? item.unitPrice : 0.0;

        // Fallback to order items using index if name or rate is missing
        if (name.isEmpty && order != null && item.itemIndex < order.items.length) {
          name = order.items[item.itemIndex].productName;
        }
        if (size.isEmpty && order != null && item.itemIndex < order.items.length) {
          size = order.items[item.itemIndex].bucketSize;
        }
        if (rate <= 0 && order != null && item.itemIndex < order.items.length) {
          rate = order.items[item.itemIndex].unitPrice;
        }
        if (name.isEmpty) name = 'Paint Product';
        if (size.isEmpty) size = '1L';

        editableItems.add({
          'name': name,
          'product_name': name,
          'bucketSize': size,
          'bucket_size': size,
          'quantity': item.quantity > 0 ? item.quantity : 1,
          'rate': rate,
          'condition': item.condition,
          'controller': TextEditingController(
            text: rate > 0 ? rate.toStringAsFixed(0) : '',
          ),
        });
      }
    } else if (order != null && order.items.isNotEmpty) {
      // Fallback to all items from painter's order
      for (final orderItem in order.items) {
        editableItems.add({
          'name': orderItem.productName,
          'product_name': orderItem.productName,
          'bucketSize': orderItem.bucketSize,
          'bucket_size': orderItem.bucketSize,
          'quantity': orderItem.quantity > 0 ? orderItem.quantity : 1,
          'rate': orderItem.unitPrice > 0 ? orderItem.unitPrice : 0.0,
          'condition': 'returned',
          'controller': TextEditingController(
            text: orderItem.unitPrice > 0 ? orderItem.unitPrice.toStringAsFixed(0) : '',
          ),
        });
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final calculatedTotal = editableItems.fold<double>(
            0,
            (sum, item) => sum + ((item['quantity'] as num) * (item['rate'] as num)).toDouble(),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Return Bill / Credit Note',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
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
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Customer: ${painter?.name ?? 'Painter'} (${painter?.phone ?? '-'})',
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
                    const SizedBox(height: 14),
                    Text(
                      'Returned Items & Refund Rates:',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ...editableItems.asMap().entries.map((entry) {
                      final item = entry.value;
                      final ctrl = item['controller'] as TextEditingController;
                      final qty = item['quantity'] as int;
                      final rate = item['rate'] as double;
                      final lineTotal = qty * rate;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${item['bucketSize']} · Qty: $qty · Condition: ${item['condition']}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSlateLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: ctrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Rate per unit (₹)',
                                      isDense: true,
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 13),
                                    onChanged: (val) {
                                      setModalState(() {
                                        item['rate'] = double.tryParse(val) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '₹${lineTotal.toStringAsFixed(0)}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Refund', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          Text(
                            '₹ ${calculatedTotal.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _generateAndUploadReturnBill(
                    returnRequest: activeRequest,
                    order: order,
                    painterName: painter?.name ?? 'Customer',
                    painterPhone: painter?.phone ?? '',
                    items: editableItems.map((e) => {
                      'name': (e['product_name'] ?? e['name'] ?? 'Item').toString(),
                      'product_name': (e['product_name'] ?? e['name'] ?? 'Item').toString(),
                      'bucketSize': (e['bucket_size'] ?? e['bucketSize'] ?? '').toString(),
                      'bucket_size': (e['bucket_size'] ?? e['bucketSize'] ?? '').toString(),
                      'quantity': e['quantity'],
                      'rate': e['rate'],
                      'amount': (e['quantity'] as num) * (e['rate'] as num),
                    }).toList(),
                    totalRefund: calculatedTotal,
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(
                  'Generate & Save Bill',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateAndUploadReturnBill({
    required ReturnRequestModel returnRequest,
    required OrderModel? order,
    required String painterName,
    required String painterPhone,
    required List<Map<String, dynamic>> items,
    required double totalRefund,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await BillExportService.generateReturnBill(
        returnRequest: returnRequest,
        order: order,
        painterName: painterName,
        painterPhone: painterPhone,
        items: items,
        customRefundTotal: totalRefund,
      );

      final ds = ref.read(dataServiceProvider);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'return_bill_${returnRequest.displayId.replaceAll('#', '')}_$timestamp.pdf';

      final billUrl = await ds.uploadReturnBillPdf(
        returnRequest.id,
        pdfBytes,
        fileName,
      );

      await ds.attachReturnBill(
        returnId: returnRequest.id,
        billUrl: billUrl,
        refundAmount: totalRefund > 0 ? totalRefund : returnRequest.refundAmount,
      );

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return bill generated and attached successfully! Visible to painter.'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {}); // refresh screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate return bill: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSlateLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DataService ds, ReturnRequestModel returnRequest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text('Delete Return Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete return request #${returnRequest.displayId}? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSlateLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSlateLight)),
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
      await ds.deleteReturnRequest(returnRequest.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return bill #${returnRequest.displayId} deleted'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        context.pop();
      }
    }
  }
}

// ─── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final ReturnStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            status.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(ReturnStatus status) {
    switch (status) {
      case ReturnStatus.requested:
        return Icons.schedule_rounded;
      case ReturnStatus.approved:
        return Icons.check_circle_rounded;
      case ReturnStatus.pickupScheduled:
        return Icons.local_shipping_rounded;
      case ReturnStatus.pickedUp:
        return Icons.inventory_2_rounded;
      case ReturnStatus.received:
        return Icons.warehouse_rounded;
      case ReturnStatus.refundProcessing:
        return Icons.account_balance_wallet_rounded;
      case ReturnStatus.refunded:
        return Icons.celebration_rounded;
      case ReturnStatus.rejected:
        return Icons.cancel_rounded;
      case ReturnStatus.cancelled:
        return Icons.do_not_disturb_on_rounded;
    }
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

// ─── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.adminCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSlateLight,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ─── Action section ────────────────────────────────────────────────────────────

class _ActionSection extends StatelessWidget {
  final ReturnRequestModel returnRequest;
  final bool isProcessing;
  final Future<void> Function(String action, {String? note}) onAction;
  final VoidCallback? onGenerateBill;

  const _ActionSection({
    required this.returnRequest,
    required this.isProcessing,
    required this.onAction,
    this.onGenerateBill,
  });

  @override
  Widget build(BuildContext context) {
    final status = returnRequest.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSlateLight,
          ),
        ),
        const SizedBox(height: 10),
        if (status == ReturnStatus.requested) ...[
          _ActionButton(
            label: '✅ Approve Return',
            color: AppColors.success,
            onTap: isProcessing
                ? null
                : () => _showNoteDialog(
                      context,
                      action: 'approve',
                      title: 'Approve Return',
                      hint: 'Optional approval note…',
                    ),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: '❌ Reject Return',
            color: AppColors.error,
            outlined: true,
            onTap: isProcessing
                ? null
                : () => _showNoteDialog(
                      context,
                      action: 'reject',
                      title: 'Reject Return',
                      hint: 'Reason for rejection (required)…',
                      required: true,
                    ),
          ),
        ],
        if (status == ReturnStatus.approved) ...[
          _ActionButton(
            label: '🚚 Schedule Pickup',
            color: AppColors.info,
            onTap: isProcessing
                ? null
                : () => _showNoteDialog(
                      context,
                      action: 'pickup_scheduled',
                      title: 'Schedule Pickup',
                      hint: 'Pickup details / date (optional)…',
                    ),
          ),
          if (onGenerateBill != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: returnRequest.billUrl != null
                  ? '🧾 View / Regenerate Return Bill'
                  : '🧾 Generate Bill for Return',
              color: const Color(0xFF7C3AED),
              onTap: isProcessing ? null : onGenerateBill,
            ),
          ],
        ],
        if (status == ReturnStatus.pickupScheduled) ...[
          _ActionButton(
            label: '📦 Mark Picked Up',
            color: const Color(0xFFD97706),
            onTap: isProcessing ? null : () => onAction('picked_up'),
          ),
          if (onGenerateBill != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: returnRequest.billUrl != null
                  ? '🧾 View / Regenerate Return Bill'
                  : '🧾 Generate Bill for Return',
              color: const Color(0xFF7C3AED),
              onTap: isProcessing ? null : onGenerateBill,
            ),
          ],
        ],
        if (status == ReturnStatus.pickedUp) ...[
          _ActionButton(
            label: '🏬 Mark Received at Warehouse',
            color: const Color(0xFF4F46E5),
            onTap: isProcessing ? null : () => onAction('received'),
          ),
          if (onGenerateBill != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: returnRequest.billUrl != null
                  ? '🧾 View / Regenerate Return Bill'
                  : '🧾 Generate Bill for Return',
              color: const Color(0xFF7C3AED),
              onTap: isProcessing ? null : onGenerateBill,
            ),
          ],
        ],
        if (status == ReturnStatus.received) ...[
          _ActionButton(
            label: '💳 Start Refund Processing',
            color: const Color(0xFF8B5CF6),
            onTap: isProcessing
                ? null
                : () => _showRefundConfirm(context, returnRequest),
          ),
          if (onGenerateBill != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: returnRequest.billUrl != null
                  ? '🧾 View / Regenerate Return Bill'
                  : '🧾 Generate Bill for Return',
              color: const Color(0xFF7C3AED),
              onTap: isProcessing ? null : onGenerateBill,
            ),
          ],
        ],
        if (status == ReturnStatus.refundProcessing) ...[
          _ActionButton(
            label: '🎉 Mark Refund Completed',
            color: AppColors.success,
            onTap: isProcessing ? null : () => onAction('refunded'),
          ),
          if (onGenerateBill != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: returnRequest.billUrl != null
                  ? '🧾 View / Regenerate Return Bill'
                  : '🧾 Generate Bill for Return',
              color: const Color(0xFF7C3AED),
              onTap: isProcessing ? null : onGenerateBill,
            ),
          ],
        ],
        if (status == ReturnStatus.refunded && onGenerateBill != null && returnRequest.billUrl != null) ...[
          _ActionButton(
            label: '🧾 View Return Bill',
            color: const Color(0xFF7C3AED),
            onTap: onGenerateBill,
          ),
        ],
      ],
    );
  }

  void _showNoteDialog(
    BuildContext context, {
    required String action,
    required String title,
    required String hint,
    bool required = false,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
                color: AppColors.textLight, fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              onAction(action,
                  note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.adminAccent,
            ),
            child: Text('Confirm',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRefundConfirm(
    BuildContext context,
    ReturnRequestModel returnRequest,
  ) {
    final computed = returnRequest.computedRefundAmount;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Start Refund Processing',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refund amount calculated from returned items:',
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '₹${computed.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This amount is calculated server-side from the returned '
              'item prices × quantities and cannot be modified from the app.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSlateLight,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction('refund_processing');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: Text('Confirm',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(label,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(label,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
    );
  }
}
