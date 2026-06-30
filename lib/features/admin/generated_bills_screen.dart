import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/order_model.dart';
import '../../core/utils/responsive.dart';

class GeneratedBillsScreen extends ConsumerStatefulWidget {
  const GeneratedBillsScreen({super.key});

  @override
  ConsumerState<GeneratedBillsScreen> createState() => _GeneratedBillsScreenState();
}

class _GeneratedBillsScreenState extends ConsumerState<GeneratedBillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _selectedPainterId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 16, 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_selectedPainterId != null) {
                                setState(() => _selectedPainterId = null);
                              } else {
                                context.go('/admin');
                              }
                            },
                            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                            color: AppColors.textPrimary,
                            splashRadius: 22,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _selectedPainterId == null ? 'Generated Bills' : 'Painter Orders',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedPainterId == null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E4DF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          indicator: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Accepted'),
                            Tab(text: 'Deleted'),
                          ],
                          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _selectedPainterId == null
                    ? TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildPaintersList(ds, showDeleted: false),
                          _buildPaintersList(ds, showDeleted: true),
                        ],
                      )
                    : _buildPainterOrders(ds, _selectedPainterId!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaintersList(DataService ds, {required bool showDeleted}) {
    final allOrders = ds.getAllOrders();
    final painterOrdersMap = <String, List<OrderModel>>{};
    
    for (final order in allOrders) {
      if (showDeleted && !order.deletedByAdmin) continue;
      if (!showDeleted && order.deletedByAdmin) continue;
      
      if (!painterOrdersMap.containsKey(order.painterId)) {
        painterOrdersMap[order.painterId] = [];
      }
      painterOrdersMap[order.painterId]!.add(order);
    }

    final paintersWithOrders = painterOrdersMap.entries.toList();

    if (paintersWithOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showDeleted ? Icons.delete_outline_rounded : Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              showDeleted ? 'No deleted orders' : 'No accepted orders',
              style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paintersWithOrders.length,
        itemBuilder: (context, index) {
          final entry = paintersWithOrders[index];
          final painterId = entry.key;
          final orders = entry.value;
          final painter = ds.getUserById(painterId);
          final totalOrders = orders.length;
          final totalAmount = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: showDeleted ? Border.all(color: AppColors.error.withValues(alpha: 0.3)) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (showDeleted ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: showDeleted ? AppColors.error : AppColors.primary,
                  size: 24,
                ),
              ),
              title: Text(
                painter?.name ?? 'Unknown Painter',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    painter?.phone ?? '',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalOrders orders • ₹${totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: showDeleted ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                setState(() {
                  _selectedPainterId = painterId;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPainterOrders(DataService ds, String painterId) {
    final painter = ds.getUserById(painterId);
    final allOrders = ds.getOrdersByPainter(painterId);
    final orders = allOrders.where((o) => !o.deletedByAdmin).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                painter?.name ?? 'Unknown Painter',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                '${orders.length} orders (excluding deleted)',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No orders found', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(order: order);
                  },
                ),
        ),
      ],
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandColor = AppColors.getBrandPrimary(order.brand);
    final dateStr = DateFormat('dd MMM yyyy').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shopping_bag_rounded, color: brandColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.brand,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: brandColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${order.items.length} items • ${order.status.toUpperCase()}',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (order.billImageUrl != null && order.billImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _viewBill(context, order.billImageUrl!),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text('View PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _viewBill(BuildContext context, String url) async {
    if (url.toLowerCase().endsWith('.pdf')) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: Text('Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: PdfPreview(
                  build: (format) async => Uint8List.fromList(response.bodyBytes),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading PDF: $e')),
          );
        }
      }
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
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
                  child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
