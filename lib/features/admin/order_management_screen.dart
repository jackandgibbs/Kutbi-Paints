import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../services/bill_export_service.dart';
import '../../services/custom_invoice_service.dart';
import '../../services/data_service.dart';
import '../shared/widgets/product_image.dart';
import '../shared/widgets/skeleton_loaders.dart';
import 'widgets/glass_order_stack.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/responsive.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() =>
      _OrderManagementScreenState();
}

class _OrderManagementScreenState
    extends ConsumerState<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _is3DMode = true; // Toggle for Glass Stack
  bool _isSelectionMode = false;
  bool _showOnlyGeneratedInvoices = false;
  final Set<String> _selectedIds = {};

  void _clearSelection() {
    if (_selectedIds.isEmpty && !_isSelectionMode) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) {
        _clearSelection();
      }
    });
    // Refresh orders every time this screen is opened so admin sees latest orders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataServiceProvider).refresh();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final invoiceService = ref.watch(customInvoiceServiceProvider);

    bool isInvoiceOrder(OrderModel o) {
      if (o.siteLocation.startsWith('Invoice #')) return true;
      return invoiceService.getByOrderId(o.id) != null;
    }

    final rawPlaced = ds.getOrdersByStatus('placed');
    final rawAccepted = ds.getOrdersByStatus('accepted');
    final rawPreparing = ds.getOrdersByStatus('preparing');
    final rawDispatched = ds.getOrdersByStatus('dispatched');
    final rawDelivered = ds.getOrdersByStatus('delivered');
    final rawCancelled = ds.getOrdersByStatus('cancelled');

    final placed = _showOnlyGeneratedInvoices ? rawPlaced.where(isInvoiceOrder).toList() : rawPlaced;
    final accepted = _showOnlyGeneratedInvoices ? rawAccepted.where(isInvoiceOrder).toList() : rawAccepted;
    final preparing = _showOnlyGeneratedInvoices ? rawPreparing.where(isInvoiceOrder).toList() : rawPreparing;
    final dispatched = _showOnlyGeneratedInvoices ? rawDispatched.where(isInvoiceOrder).toList() : rawDispatched;
    final delivered = _showOnlyGeneratedInvoices ? rawDelivered.where(isInvoiceOrder).toList() : rawDelivered;
    final cancelled = _showOnlyGeneratedInvoices ? rawCancelled.where(isInvoiceOrder).toList() : rawCancelled;

    List currentTabOrders = [];
    String currentStatus = 'placed';
    switch (_tabCtrl.index) {
      case 0:
        currentTabOrders = placed;
        currentStatus = 'placed';
        break;
      case 1:
        currentTabOrders = accepted;
        currentStatus = 'accepted';
        break;
      case 2:
        currentTabOrders = preparing;
        currentStatus = 'preparing';
        break;
      case 3:
        currentTabOrders = dispatched;
        currentStatus = 'dispatched';
        break;
      case 4:
        currentTabOrders = delivered;
        currentStatus = 'delivered';
        break;
      case 5:
        currentTabOrders = cancelled;
        currentStatus = 'cancelled';
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSelectionMode
              ? AppBar(
                  key: const ValueKey('selection_appbar_orders'),
                  backgroundColor: AppColors.primary,
                  elevation: 8,
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _clearSelection,
                  ),
                  title: Text(
                    '${_selectedIds.length} Selected',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _selectedIds.length == currentTabOrders.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == currentTabOrders.length) {
                            _selectedIds.clear();
                            _isSelectionMode = false;
                          } else {
                            _selectedIds.addAll(
                                currentTabOrders.map((o) => o.id as String));
                          }
                        });
                      },
                      tooltip: 'Select All',
                    ),
                    _buildBulkActionsMenu(currentStatus),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: _buildSelectionTabPlaceholder(),
                  ),
                )
              : AppBar(
                  key: const ValueKey('normal_appbar_orders'),
                  leading: IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/admin');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                  ),
                  title: Text('Order Management',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  actions: [
                    // Filter Toggle for Generated Invoices
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showOnlyGeneratedInvoices = !_showOnlyGeneratedInvoices;
                          _clearSelection();
                        });
                      },
                      icon: Icon(
                        _showOnlyGeneratedInvoices ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
                        color: _showOnlyGeneratedInvoices ? const Color(0xFFF97316) : null,
                      ),
                      tooltip: _showOnlyGeneratedInvoices ? 'Show All Orders' : 'Filter Generated Invoices Only',
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                             _is3DMode = !_is3DMode;
                             if (_is3DMode) _clearSelection();
                        });
                      },
                      icon: Icon(_is3DMode ? Icons.view_headline_rounded : Icons.view_carousel_rounded),
                      tooltip: _is3DMode ? 'Switch to List' : 'Switch to 3D Stack',
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'New (${placed.length})'),
                      Tab(text: 'Accepted (${accepted.length})'),
                      Tab(text: 'Preparing (${preparing.length})'),
                      Tab(text: 'Dispatched (${dispatched.length})'),
                      Tab(text: 'Delivered (${delivered.length})'),
                      Tab(text: 'Cancelled (${cancelled.length})'),
                    ],
                    labelStyle: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
      body: !ds.isLoaded 
        ? ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, _) => const OrderTileSkeleton(),
          )
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Column(
                children: [
                  if (_showOnlyGeneratedInvoices)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFFFFF7ED),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_rounded, size: 16, color: Color(0xFFF97316)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing Generated Invoices Only',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFC2410C)),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _showOnlyGeneratedInvoices = false),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFC2410C)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _orderList(ds, 'placed', placed),
                        _orderList(ds, 'accepted', accepted),
                        _orderList(ds, 'preparing', preparing),
                        _orderList(ds, 'dispatched', dispatched),
                        _orderList(ds, 'delivered', delivered),
                        _cancelledOrderList(ds, cancelled),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _orderList(DataService ds, String status, [List<OrderModel>? ordersOverride]) {
    final orders = ordersOverride ?? ds.getOrdersByStatus(status);

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - 180, // Adjust for AppBar & TabBar
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No ${_statusLabel(status).toLowerCase()} orders',
                    style:
                        GoogleFonts.poppins(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    if (_is3DMode && (status == 'placed' || status == 'accepted' || status == 'preparing')) {
      return GlassOrderStack(
        orders: orders,
        onStatusUpdate: (orderId, nextStatus) {
          ref.read(dataServiceProvider).updateOrderStatus(orderId, nextStatus);
          setState(() {});
        },
        onTapDetails: (orderId) => context.push('/admin/order-detail/$orderId'),
        getNextStatus: _getNextStatus,
        getActionLabel: _getActionLabel,
        getActionIcon: _getActionIcon,
        getPainterName: (id) => ds.getUserById(id)?.name ?? 'Customer',
        getPainterPhone: (id) => ds.getUserById(id)?.phone ?? '',
      );
    }

    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final order = orders[i];
        final brandColor = AppColors.getBrandPrimary(order.brand);
        final linkedInvoice = ref.watch(customInvoiceServiceProvider).getByOrderId(order.id);
        final isSelected = _selectedIds.contains(order.id);

        return GestureDetector(
          onLongPress: () {
            setState(() {
              if (!_isSelectionMode) {
                _isSelectionMode = true;
                _selectedIds.add(order.id);
              } else {
                if (isSelected) {
                  _selectedIds.remove(order.id);
                  if (_selectedIds.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedIds.add(order.id);
                }
              }
            });
          },
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(order.id);
                  if (_selectedIds.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedIds.add(order.id);
                }
              });
            } else {
               context.push('/admin/order-detail/${order.id}');
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.03) : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Generated Invoice Banner if linked
              if (linkedInvoice != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626)).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626)).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  linkedInvoice.invoiceNumber,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    linkedInvoice.isPurchase ? 'PURCHASE BILL' : 'RETURN BILL',
                                    style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Generated Invoice • ₹${linkedInvoice.totalAmount.toStringAsFixed(0)} • ${DateFormat('dd MMM yyyy').format(linkedInvoice.date)}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final pdfBytes = await BillExportService.generateCustomInvoicePdf(linkedInvoice);
                            await Printing.layoutPdf(
                              onLayout: (format) async => pdfBytes,
                              name: '${linkedInvoice.invoiceNumber}.pdf',
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error viewing invoice: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.print_rounded, size: 14),
                        label: const Text('View Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: linkedInvoice.isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Row(
                children: [
                  Stack(
                    children: [
                      ProductImage(
                        imageUrl: order.items.first.productImageUrl,
                        productId: order.items.first.productId,
                        brand: order.brand,
                        size: 44,
                        borderRadius: 12,
                      ),
                      if (isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.painterName?.isNotEmpty == true
                              ? order.painterName!
                              : (ds.getUserById(order.painterId)?.name ?? 'Customer'),
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${order.brand} • ${DateFormat('dd MMM, hh:mm a').format(order.createdAt)}',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSelectionMode) ...[
                    GestureDetector(
                      onTap: () => _handleDeleteSingleOrder(order.id),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.error),
                    ),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: () => context
                        .push('/admin/order-detail/${order.id}'),
                    child: const Icon(Icons.open_in_new_rounded,
                        size: 20, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod == 'cod' ? 'COD' : 'Online'}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '📍 ${order.siteLocation}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textLight),
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

              // Item Details Summary (Shows Products with Name, Size, Qty, Rate, Total, and Shade)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProductImage(
                                imageUrl: item.productImageUrl,
                                productId: item.productId,
                                brand: order.brand,
                                size: 28,
                                borderRadius: 6,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.productName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${item.totalPrice > 0 ? item.totalPrice.toStringAsFixed(0) : (item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${item.bucketSize} × ${item.quantity}${item.unitPrice > 0 ? ' (@ ₹${item.unitPrice.toStringAsFixed(0)})' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        if (item.shadeCode != null && item.shadeCode!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: brandColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              'SHADE: ${item.shadeCode}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: brandColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
              const SizedBox(height: 16),

              // Action buttons (hidden in selection mode)
              if (!_isSelectionMode) _buildActions(order, brandColor),
            ],
          ),
        ),
        );
      },
      ),
    );
  }

  Widget _buildActions(dynamic order, Color brandColor) {
    final nextStatus = _getNextStatus(order.status);
    if (order.status == 'returned') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('↩️ Returned',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C3AED))),
      );
    }
    if (nextStatus == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('✅ Delivered',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success)),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ref
              .read(dataServiceProvider)
              .updateOrderStatus(order.id, nextStatus);
          setState(() {});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(_getActionIcon(nextStatus),
            color: Colors.white, size: 18),
        label: Text(
          _getActionLabel(nextStatus),
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  String? _getNextStatus(String current) {
    switch (current) {
      case 'placed':
      case 'udhaari_pending_approval':
      case 'pending_bill':
      case 'bill_sent':
      case 'billed':
        return 'accepted';
      case 'accepted':
        return 'preparing';
      case 'preparing':
        return 'dispatched';
      case 'dispatched':
        return 'delivered';
      default:
        return null;
    }
  }

  String _getActionLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accept Order';
      case 'preparing':
        return 'Start Preparing';
      case 'dispatched':
        return 'Mark Dispatched';
      case 'delivered':
        return 'Mark Delivered';
      default:
        return '';
    }
  }

  IconData _getActionIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'preparing':
        return Icons.build_circle_rounded;
      case 'dispatched':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  String _statusLabel(String s) {
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _cancelledOrderList(DataService ds, [List<OrderModel>? ordersOverride]) {
    final orders = ordersOverride ?? ds.getOrdersByStatus('cancelled');

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - 180,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No cancelled orders', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
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
          final painter = ds.getUserById(order.painterId);
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                    const Spacer(),
                    Text(DateFormat('dd MMM, hh:mm a').format(order.createdAt), style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(painter?.name ?? order.painterName ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(painter?.phone ?? order.painterPhone ?? '', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Expanded(child: Text(order.siteLocation, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          ProductImage(imageUrl: item.productImageUrl, productId: item.productId, brand: order.brand, size: 24, borderRadius: 6),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.productName} (${item.bucketSize}${item.shadeCode != null && item.shadeCode!.isNotEmpty ? ' • ${item.shadeCode}' : ''}) x${item.quantity}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionTabPlaceholder() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        'Tap items to toggle · Long press to exit',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white70,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildBulkActionsMenu(String currentStatus) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: _handleBulkAction,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (ctx) {
        if (currentStatus == 'placed' || currentStatus == 'accepted') {
          return [
            _bulkItem(currentStatus == 'placed' ? 'accepted' : 'preparing', 
              currentStatus == 'placed' ? Icons.check_circle_rounded : Icons.build_circle_rounded, 
              currentStatus == 'placed' ? 'Accept Selected' : 'Start Preparing Selected', 
              AppColors.primary),
            const PopupMenuDivider(),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        } else if (currentStatus == 'preparing') {
          return [
            _bulkItem('dispatched', Icons.local_shipping_rounded, 'Mark Dispatched', AppColors.primary),
            const PopupMenuDivider(),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        } else if (currentStatus == 'dispatched') {
          return [
            _bulkItem('delivered', Icons.done_all_rounded, 'Mark Delivered', AppColors.success),
            const PopupMenuDivider(),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        } else if (currentStatus == 'delivered') {
          return [
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        }
        return [];
      },
    );
  }

  PopupMenuItem<String> _bulkItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _handleBulkAction(String action) async {
    final ds = ref.read(dataServiceProvider);
    final count = _selectedIds.length;
    
    // Confirmation for destructive actions
    if (action == 'delete') {
      final confirmed = await _showConfirmDialog(action, count);
      if (!confirmed || !mounted) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Processing $count orders...'), duration: const Duration(seconds: 1)),
    );

    final ids = List<String>.from(_selectedIds);
    _clearSelection();

    try {
      for (final id in ids) {
        if (action == 'delete') {
          await ds.deleteOrder(id);
        } else {
          await ds.updateOrderStatus(id, action);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed $count orders'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during bulk action: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSingleOrder(String orderId) async {
    final confirmed = await _showConfirmDialog('delete', 1);
    if (!confirmed || !mounted) return;
    
    try {
      await ref.read(dataServiceProvider).deleteOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String action, int count) async {
    String title = 'Confirm Action';
    String message = 'Are you sure you want to perform this action on $count orders?';
    
    if (action == 'delete') {
      title = 'Delete Orders';
      message = 'This will permanently delete $count orders. This action cannot be undone.';
    }

    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'delete' ? AppColors.error : AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action == 'delete' ? 'Delete' : 'Confirm', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }
}

