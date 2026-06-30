import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/product_image.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/responsive.dart';

final selectedPaymentsProvider = StateProvider<Set<String>>((ref) => {});

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Tab index 0: Cash, 1: Online, 2: Udhaari

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading payments...'),
      );
    }

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
                          if (ref.watch(selectedPaymentsProvider).isNotEmpty) ...[
                            Text(
                              '${ref.watch(selectedPaymentsProvider).length} Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            const Spacer(),
                            _clayDeleteButton(context, ref),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => ref.read(selectedPaymentsProvider.notifier).state = {},
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.textSecondary,
                            ),
                          ] else ...[
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                              color: AppColors.textPrimary,
                              splashRadius: 22,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Payments Board',
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
                                color: AppColors.adminPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.payments_rounded, size: 20, color: AppColors.adminPrimary),
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
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          color: AppColors.adminPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Cash'),
                          Tab(text: 'Online'),
                          Tab(text: 'Udhaari'),
                          Tab(text: 'Cancelled'),
                        ],
                        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        splashBorderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Content ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PaymentTabContent(methodType: 'cash'),
                    _PaymentTabContent(methodType: 'online'),
                    _UdhaariTabContent(),
                    _CancelledTabContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTabContent extends ConsumerWidget {
  final String methodType;
  const _PaymentTabContent({required this.methodType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    // Get orders matching methodType and not fully paid
    final orders = ds.getAllOrders().where((o) => 
      o.paymentMethod.startsWith(methodType) && 
      (o.paymentStatus == 'pending' || o.paymentStatus == 'partially_paid')
    ).toList();

    final completedOrders = ds.getAllOrders().where((o) =>
      o.paymentMethod.startsWith(methodType) && o.paymentStatus == 'fully_paid'
    ).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDE8),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.85),
                  blurRadius: 8,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: const Color(0xFFD1CCC4).withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: TabBar(
              labelColor: AppColors.adminPrimary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.adminPrimary,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(context, orders, ds, isPending: true),
                _buildOrderList(context, completedOrders, ds, isPending: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<OrderModel> orders, DataService ds, {required bool isPending}) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No $methodType orders.', style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderPaymentCard(order: order, isPending: isPending, isUdhaari: false);
      },
    );
  }
}

class _UdhaariTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    // Show orders with udhaari_pending_approval or to_be_revealed status
    final pendingOrders = ds.getAllOrders().where((o) => 
      o.status == 'udhaari_pending_approval' || o.status == 'to_be_revealed'
    ).toList();
    final activeUdhaari = ds.getAllOrders().where((o) =>
      o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari'
    ).toList();
    final completedUdhaari = ds.getAllOrders().where((o) =>
      o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari_completed'
    ).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDE8),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.85),
                  blurRadius: 8,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: const Color(0xFFD1CCC4).withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: TabBar(
              labelColor: AppColors.adminPrimary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.adminPrimary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: 'Requests (${pendingOrders.length})'),
                Tab(text: 'Active (${activeUdhaari.length})'),
                Tab(text: 'Paid (${completedUdhaari.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _UdhaariRequestsList(orders: pendingOrders),
                _buildList(activeUdhaari, context, isPending: false, showMarkPaid: true),
                _buildList(completedUdhaari, context, isPending: false, showMarkPaid: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<OrderModel> orders, BuildContext context, {required bool isPending, required bool showMarkPaid}) {
    if (orders.isEmpty) {
      return Center(child: Text('No orders here.', style: GoogleFonts.poppins(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderPaymentCard(order: orders[index], isPending: isPending, isUdhaari: true, showMarkPaid: showMarkPaid);
      },
    );
  }
}

/// Widget for displaying udhaari requests with approve button
class _UdhaariRequestsList extends ConsumerWidget {
  final List<OrderModel> orders;
  const _UdhaariRequestsList({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(child: Text('No pending udhaari requests.', style: GoogleFonts.poppins(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _UdhaariRequestCard(order: orders[index]);
      },
    );
  }
}

/// Card for udhaari request with approve button
class _UdhaariRequestCard extends ConsumerWidget {
  final OrderModel order;
  const _UdhaariRequestCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final painter = ds.getUserById(order.painterId);
    final brandColor = AppColors.getBrandPrimary(order.brand);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(18),
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
      child: Column(
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
                  child: Icon(Icons.receipt_rounded, color: brandColor, size: 24),
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
                        '${order.brand} • ₹${order.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
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
              children: order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName} (${item.bucketSize}) x${item.quantity}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          // Action buttons - different for to_be_revealed vs udhaari_pending_approval
          Padding(
            padding: const EdgeInsets.all(16),
            child: order.status == 'to_be_revealed'
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showGenerateBillDialog(context, ref),
                          icon: const Icon(Icons.receipt_rounded, size: 18),
                          label: Text('Generate Bill',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _confirmDeleteRequest(context, ref),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveUdhaari(context, ref),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text('Approve',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _confirmDeleteRequest(context, ref),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUdhaari(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(dataServiceProvider).approveUdhaariRequest(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order approved and moved to Order Management!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showGenerateBillDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _GenerateBillSheet(order: order),
    );
  }

  Future<void> _confirmDeleteRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Request?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will mark the request as deleted. The painter will see it in their "Deleted Orders" tab.',
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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

/// Bottom sheet for generating bill for to_be_revealed orders
class _GenerateBillSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  const _GenerateBillSheet({required this.order});

  @override
  ConsumerState<_GenerateBillSheet> createState() => _GenerateBillSheetState();
}

class _GenerateBillSheetState extends ConsumerState<_GenerateBillSheet> {
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateBill() async {
    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the total amount')),
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ds = ref.read(dataServiceProvider);
      // Update order with amount and move to udhaari_pending_approval
      await ds.generateBillForRevealLater(widget.order.id, amount);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill generated! Order ready for approval.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Generate Bill',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the total amount for this order',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _generateBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Generate Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final cancelledOrders = ds.getOrdersByStatus('cancelled');

    if (cancelledOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No cancelled orders', style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cancelledOrders.length,
      itemBuilder: (context, index) {
        final order = cancelledOrders[index];
        final painter = ds.getUserById(order.painterId);
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('CANCELLED', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.paymentMethod == 'udhaari' 
                        ? (order.paymentStatus == 'udhaari' ? 'Active Udhaari' : 'Udhaari Request')
                        : order.paymentMethod.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ),
                  const Spacer(),
                  Text(order.createdAt.toString().substring(0, 16), style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(painter?.name ?? order.painterName ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(painter?.phone ?? order.painterPhone ?? '', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.siteLocation, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary))),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text('${item.productName} (${item.bucketSize}) x${item.quantity}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderPaymentCard extends ConsumerWidget {
  final OrderModel order;
  final bool isPending;
  final bool isUdhaari;
  final bool showMarkPaid;

  const _OrderPaymentCard({required this.order, required this.isPending, required this.isUdhaari, this.showMarkPaid = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedPaymentsProvider);
    final isSelected = selectedIds.contains(order.id);
    final isSelectionMode = selectedIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () {
        if (!isSelectionMode) {
          ref.read(selectedPaymentsProvider.notifier).update((state) => {...state, order.id});
        } else {
          ref.read(selectedPaymentsProvider.notifier).update((state) {
            final newState = Set<String>.from(state);
            isSelected ? newState.remove(order.id) : newState.add(order.id);
            return newState;
          });
        }
      },
      onTap: isSelectionMode ? () {
          ref.read(selectedPaymentsProvider.notifier).update((state) {
            final newState = Set<String>.from(state);
            isSelected ? newState.remove(order.id) : newState.add(order.id);
            return newState;
          });
        } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.03) : const Color(0xFFF0EDE8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Order #${order.id.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (!isSelectionMode) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _handleDeleteSingleOrder(context, ref, order.id),
                        child: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.paymentStatus == 'partially_paid')
                      Text(
                        'Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey, fontSize: 12, decoration: TextDecoration.lineThrough),
                      ),
                    Text(
                      isPending ? 'Pending: ₹${order.remainingAmount.toStringAsFixed(0)}' : '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isPending ? Colors.red.shade600 : AppColors.adminPrimary, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.painterName ?? 'Unknown', 
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                if (order.paymentStatus == 'partially_paid')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('Partially Paid: ₹${order.paidAmount}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Site location
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: AppColors.textLight),
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
            const SizedBox(height: 12),
            if (!isSelectionMode && isPending && !isUdhaari)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showVerifyPaymentDialog(context, ref, order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Verify Payment', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            if (!isSelectionMode && !isPending && !isUdhaari && order.paymentStatus == 'partially_paid')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showVerifyPaymentDialog(context, ref, order),
                  child: Text('Update Remaining Payment', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.bold)),
                ),
              ),
            if (!isSelectionMode && isPending && isUdhaari)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: order.isPendingReveal ? null : () => _showUdhaariDialog(context, ref, order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: order.isPendingReveal ? Colors.grey : AppColors.warning,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    order.isPendingReveal ? 'Awaiting Bill Amount' : 'Review Udhaari Request', 
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            if (!isSelectionMode && showMarkPaid)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showMarkPaidDialog(context, ref, order),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Mark as Paid', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            if (order.paymentStatus == 'udhaari_completed')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 6),
                    Text('Settled', style: GoogleFonts.poppins(color: const Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
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
  }

  void _handleDeleteSingleOrder(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF0EDE8),
        title: Text('Delete Payment?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete this payment order. It cannot be undone.', style: GoogleFonts.poppins(fontSize: 14)),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleted successfully'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVerifyPaymentDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final ds = ref.read(dataServiceProvider);
    final amountCtrl = TextEditingController(text: order.remainingAmount.toStringAsFixed(0));
    final refIdCtrl = TextEditingController();
    bool isProcessing = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final amountReceived = double.tryParse(amountCtrl.text) ?? 0;
          final isFull = amountReceived >= (order.remainingAmount - 0.01); // Handle small rounding errors
          
          return AlertDialog(
            title: Text('Verify ${order.paymentMethod.toUpperCase()} Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Due: ₹${order.remainingAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    onChanged: (_) => setState(() {}), // Trigger rebuild to update button text
                  ),
                  if (order.paymentMethod.contains('online')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: refIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference ID / UTR (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx), 
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isProcessing || amountReceived <= 0 ? null : () async {
                  setState(() => isProcessing = true);
                  FocusScope.of(ctx).unfocus(); // Ensure keyboard is dismissed and focus cleared
                  
                  try {
                    final currentUser = ref.read(currentUserProvider);
                    await ds.verifyPayment(
                      orderId: order.id,
                      amountReceived: amountReceived,
                      method: order.paymentMethod,
                      isFull: isFull,
                      adminId: currentUser?.id ?? 'admin',
                      referenceId: refIdCtrl.text,
                    );
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setState(() => isProcessing = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verification Failed: ${e.toString()}'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                ),
                child: isProcessing 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isFull ? 'Accept as Full' : 'Accept as Partial', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showUdhaariDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final ds = ref.read(dataServiceProvider);
    bool enableInterest = false;
    double interestRate = 0.0;
    bool isProcessing = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            double calculatedInterest = enableInterest ? (order.totalAmount * (interestRate / 100)) : 0;
            return AlertDialog(
              title: Text('Udhaari Request', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${order.totalAmount}', style: GoogleFonts.poppins(fontSize: 16)),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Apply Interest'),
                      value: enableInterest,
                      onChanged: isProcessing ? null : (v) => setState(() => enableInterest = v),
                    ),
                    if (enableInterest) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Interest Rate (% p.a.)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() {
                            interestRate = double.tryParse(v) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Calculated Interest: ₹${calculatedInterest.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx), 
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isProcessing ? null : () async {
                    setState(() => isProcessing = true);
                    FocusScope.of(ctx).unfocus();
                    
                    try {
                      await ds.markUdhaari(
                        orderId: order.id,
                        enableInterest: enableInterest,
                        interestRate: interestRate,
                        interestAmount: calculatedInterest,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => isProcessing = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Verification Failed: ${e.toString()}'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.warning.withOpacity(0.5),
                  ),
                  child: isProcessing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Approve Udhaari', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showMarkPaidDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final ds = ref.read(dataServiceProvider);
    final totalWithInterest = order.totalAmount + (order.udhaariInterestAmount ?? 0);
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Mark Udhaari as Paid', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Painter: ${order.painterName ?? 'Unknown'}', style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 8),
                Text('Amount: ₹${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 14)),
                if ((order.udhaariInterestAmount ?? 0) > 0) ...[
                  Text('Interest: ₹${order.udhaariInterestAmount!.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                  Text('Total Due: ₹${totalWithInterest.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will mark the udhaari as fully paid and settle the painter\'s debt.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing ? null : () async {
                  setState(() => isProcessing = true);
                  try {
                    await ds.markUdhaariCompleted(order.id);
                    if (context.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Udhaari marked as paid!', style: GoogleFonts.poppins(color: Colors.white)),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => isProcessing = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: ${e.toString()}'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                icon: isProcessing
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Confirm Paid', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _clayDeleteButton(BuildContext context, WidgetRef ref) {
  return GestureDetector(
    onTap: () {
      final selectedIds = ref.read(selectedPaymentsProvider);
      if (selectedIds.isEmpty) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFF0EDE8),
          title: Text(
            'Delete ${selectedIds.length} Payments?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'This action completely removes the orders from the database. It cannot be undone.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final idsList = selectedIds.toList();
                  ref.read(selectedPaymentsProvider.notifier).state = {};
                  await ref.read(dataServiceProvider).bulkDeleteOrders(idsList);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Orders deleted permanently'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
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
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    },
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
          const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
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