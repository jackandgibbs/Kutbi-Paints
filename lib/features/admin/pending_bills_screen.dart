import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../services/bill_export_service.dart';
import '../../services/notification_service.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/responsive.dart';

/// Admin screen for managing pending bills.
/// Tab 1: All Bills — orders waiting for admin to upload a bill.
/// Tab 2: Previous Bills — orders where a bill was already sent.
class PendingBillsScreen extends ConsumerStatefulWidget {
  const PendingBillsScreen({super.key});

  @override
  ConsumerState<PendingBillsScreen> createState() => _PendingBillsScreenState();
}

class _PendingBillsScreenState extends ConsumerState<PendingBillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final Set<String> _selectedOrderIds = {};
  bool get _isSelectionMode => _selectedOrderIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final pendingBills = ds.getOrdersForBilling();
    final toBeRevealed = ds.getOrdersToBeRevealed();
    final previousBills = ds.getOrdersWithBills();
    final deletedOrders = ds.getAllOrders().where((o) => o.deletedByAdmin).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
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
                          if (_isSelectionMode) ...[
                            Text(
                              '${_selectedOrderIds.length} Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            const Spacer(),
                            _clayDeleteButton(),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _clearSelection,
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.textSecondary,
                            ),
                          ] else ...[
                            IconButton(
                              onPressed: () => context.go('/admin'),
                              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                              color: AppColors.textPrimary,
                              splashRadius: 22,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Pending Bills',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
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
                      ),
                      child: TabBar(
                        controller: _tabCtrl,
                        isScrollable: false,
                        indicator: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Pending (${pendingBills.length})'),
                          Tab(text: 'To Reveal (${toBeRevealed.length})'),
                          Tab(text: 'Previous (${previousBills.length})'),
                          Tab(text: 'Deleted (${deletedOrders.length})'),
                        ],
                        labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelPadding: EdgeInsets.zero,
                        splashBorderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Content ──
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildOrderList(ds, pendingBills, isPending: true),
                    _buildOrderList(ds, toBeRevealed, isPending: false, isToReveal: true),
                    _buildOrderList(ds, previousBills, isPending: false),
                    _buildOrderList(ds, deletedOrders, isPending: false, isDeleted: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(DataService ds, List orders,
      {required bool isPending, bool isToReveal = false, bool isDeleted = false}) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - 250,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDeleted
                      ? Icons.delete_outline_rounded
                      : isPending
                          ? Icons.receipt_long_rounded
                          : Icons.check_circle_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  isDeleted 
                      ? 'No deleted orders'
                      : isPending ? 'No pending bills' : 'No previous bills',
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final order = orders[i];
          final isSelected = _selectedOrderIds.contains(order.id);
          final painter = ds.getUserById(order.painterId);
          final brandColor = AppColors.getBrandPrimary(order.brand);

          return GestureDetector(
            onLongPress: () {
              HapticFeedback.heavyImpact();
              _toggleSelection(order.id);
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(order.id);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? Border.all(color: const Color(0xFF7C3AED), width: 2)
                    : null,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  else ...[
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
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    brandColor.withValues(alpha: 0.2),
                                    brandColor.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: () {
                                final brandLower = order.brand.toLowerCase();
                                String? imageUrl;
                                if (brandLower.contains('birla')) {
                                  imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus.png';
                                } else if (brandLower.contains('asian')) {
                                  imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/ap.png';
                                } else if (brandLower.contains('berger')) {
                                  imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/berger.png';
                                }
                                return imageUrl != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.network(imageUrl, fit: BoxFit.contain),
                                      )
                                    : Icon(Icons.receipt_rounded, color: brandColor, size: 24);
                              }(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    painter?.name ?? 'Unknown Painter',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${order.brand} • ${DateFormat('dd MMM, hh:mm a').format(order.createdAt)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isSelectionMode) ...[
                              GestureDetector(
                                onTap: () => _handleDeleteSingleOrder(order.id),
                                child: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isToReveal
                                    ? const Color(0xFFFF9800).withValues(alpha: 0.1)
                                    : (isPending
                                        ? AppColors.warning.withValues(alpha: 0.1)
                                        : AppColors.success.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isToReveal ? 'TO REVEAL' : (isPending ? 'PENDING' : 'BILL SENT'),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isToReveal
                                      ? const Color(0xFFFF9800)
                                      : (isPending ? AppColors.warning : AppColors.success),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Items summary
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      ProductImage(
                                        imageUrl: item.productImageUrl,
                                        productId: item.productId,
                                        brand: order.brand,
                                        size: 24,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.productName} (${item.bucketSize}) x${item.quantity}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (item.shadeCode != null && item.shadeCode!.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(top: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: brandColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'SHADE: ${item.shadeCode}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: brandColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Site location
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 14, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.siteLocation,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => AppUtils.copyAddressToClipboard(context, order.siteLocation),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              color: AppColors.textLight,
                              tooltip: 'Copy Address',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // Action
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: isPending
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showGenerateBillDialog(order),
                                      icon: const Icon(Icons.receipt_rounded,
                                          size: 18),
                                      label: Text('Generate Bill',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _confirmRevealLater(order),
                                      icon: const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFFF9800)),
                                      label: Text('Reveal Later',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFFF9800))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFFF9800)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : isToReveal
                                ? SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _confirmAcceptUdhaari(order),
                                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                                      label: Text('Accept Udhaari',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF9800),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  )
                                : order.status == 'to_be_revealed'
                                    ? SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showGenerateBillDialog(order),
                                          icon: const Icon(Icons.receipt_rounded, size: 18),
                                          label: Text('Generate Bill',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C3AED),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.check_circle_rounded,
                                                  size: 16,
                                                  color: AppColors.success),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Bill Sent',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 38,
                                    width: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      onPressed: () =>
                                          _showBillPreview(order.billImageUrl!),
                                      icon: const Icon(Icons.visibility_rounded,
                                          size: 18),
                                      padding: EdgeInsets.zero,
                                      color: AppColors.textSecondary,
                                      tooltip: 'View Bill',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

void _toggleSelection(String orderId) {
  setState(() {
    if (_selectedOrderIds.contains(orderId)) {
      _selectedOrderIds.remove(orderId);
    } else {
      _selectedOrderIds.add(orderId);
    }
  });
}

void _clearSelection() {
  setState(() {
    _selectedOrderIds.clear();
  });
}

Widget _clayDeleteButton() {
  return GestureDetector(
    onTap: _confirmBulkDelete,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
          BoxShadow(
            color: const Color(0xFFD1CCC4).withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
          const SizedBox(width: 6),
          Text(
            'Delete',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    ),
  );
}

void _confirmBulkDelete() {
  if (_selectedOrderIds.isEmpty) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF0EDE8),
      title: Text('Bulk Delete Orders?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text(
        'Are you sure you want to delete ${_selectedOrderIds.length} selected orders? This action cannot be undone.',
        style: GoogleFonts.poppins(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textLight)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final orderIds = _selectedOrderIds.toList();
            _clearSelection();
            try {
              await ref.read(dataServiceProvider).bulkDeleteOrders(orderIds);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${orderIds.length} orders deleted successfully'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Delete All', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

  void _showGenerateBillDialog(dynamic order) {
    final ds = ref.read(dataServiceProvider);
    final painter = ds.getUserById(order.painterId);

    final editableItems = order.items.map<Map<String, dynamic>>((item) => {
      'name': item.productName,
      'bucketSize': item.bucketSize,
      'quantity': item.quantity,
      'rate': (item.unitPrice > 0 ? item.unitPrice : 0).toDouble(),
    }).toList();

    bool hideAmount = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double calculatedTotal = editableItems.fold<double>(0, (sum, item) => sum + ((item['quantity'] as num) * (item['rate'] as num)).toDouble());

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Generate Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Text('Billing for: ${painter?.name ?? 'Customer'}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Enter rates:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: editableItems.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final item = editableItems[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] as String, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('Qty: ${item['quantity']}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                  const SizedBox(height: 12),
                  // Hide Amount Checkbox
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hideAmount ? const Color(0xFFFF9800).withValues(alpha: 0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: hideAmount ? const Color(0xFFFF9800).withValues(alpha: 0.3) : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: hideAmount,
                          onChanged: (val) => setModalState(() => hideAmount = val ?? false),
                          activeColor: const Color(0xFFFF9800),
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hide amount from painter', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('Painter will see "--" instead of amount', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        Text(hideAmount ? '--' : '₹ ${calculatedTotal.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
              ElevatedButton(
                onPressed: () async {
                  if (calculatedTotal <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Please enter rates')));
                    return;
                  }
                  
                  // Show loading
                  showDialog(
                    context: this.context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  try {
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

                    // Upload PDF to storage with timestamp to avoid cache
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final pdfUrl = await ds.uploadBillPdf(
                      order.id,
                      pdfBytes,
                      'bill_${order.id.substring(0, 8)}_$timestamp.pdf',
                    );

                    final List<OrderItemModel> updatedItems = order.items.asMap().entries.map<OrderItemModel>((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final rate = (editableItems[i]['rate'] as num).toDouble();
                      return item.copyWith(unitPrice: rate, totalPrice: rate * item.quantity);
                    }).toList();

                    await ds.uploadBill(order.id, pdfUrl, calculatedTotal, customItems: updatedItems, hideAmount: hideAmount);

                    NotificationService.showBillUploaded(orderId: order.id, brand: order.brand, amount: hideAmount ? 0 : calculatedTotal);

                    if (!mounted) return;
                    Navigator.pop(this.context); // Close loading
                    Navigator.pop(ctx); // Close dialog
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Bill generated & sent to painter!'), backgroundColor: AppColors.success),
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(this.context); // Close loading
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Generate & Send', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleDeleteSingleOrder(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Bill?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete this order. It cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataServiceProvider).deleteOrder(orderId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill deleted successfully'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRevealLater(dynamic order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reveal Later?',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'The order will be accepted without a bill or amount. The painter will see "Amount to be revealed by admin". You can upload the bill later from the "To Be Revealed" tab.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataServiceProvider).revealLater(order.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order marked as Reveal Later!'),
                      backgroundColor: Color(0xFFFF9800),
                    ),
                  );
                  setState(() {});
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Yes, Reveal Later',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmAcceptUdhaari(dynamic order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Accept Udhaari?',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'This will accept the order as udhaari without a bill. You can generate the bill later from the History tab.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataServiceProvider).approveUdhaariRequest(order.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Udhaari accepted!'), backgroundColor: Color(0xFFFF9800)),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Yes, Accept', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showBillPreview(String url) async {
    // If it's a PDF, open with printing package by fetching the bytes
    if (url.toLowerCase().endsWith('.pdf')) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        
        final response = await http.get(Uri.parse(url));
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        
        if (response.statusCode == 200) {
          await Printing.layoutPdf(
            onLayout: (_) async => response.bodyBytes,
            name: 'Bill Preview',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load PDF'), backgroundColor: AppColors.error),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
      return;
    }
    
    // Otherwise show as image
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (ctx, err, stack) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
