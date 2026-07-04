import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';
import '../shared/widgets/skeleton_loaders.dart';
import '../../core/utils/responsive.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _searchQuery = '';
  String _selectedBrand = 'All';

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    List<ProductModel> products =
        ds.getProductsWithLowStockState(brand: _selectedBrand == 'All' ? null : _selectedBrand);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              p.colorCode.toLowerCase().contains(q) ||
              p.colorName.toLowerCase().contains(q))
          .toList();
    }

    // Calculate low stock stats
    final totalLowStock = products.where((p) => p.isLowStock).length;
    final totalOutOfStock = products.where((p) => p.isEffectivelyOutOfStock).length;

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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                        color: AppColors.textPrimary,
                        splashRadius: 22,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inventory Pulse',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Overall Stock Tracking',
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
                          color: AppColors.adminPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.adminPrimary),
                            const SizedBox(width: 6),
                            Text(
                              '${products.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.adminPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => context.push('/admin/brands'),
                        icon: const Icon(Icons.business_rounded, color: AppColors.adminPrimary),
                        tooltip: 'Manage Brands',
                      ),
                      IconButton(
                        onPressed: () => _exportPDF(products),
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                        tooltip: 'Export PDF',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──
              Expanded(
                child: RefreshIndicator(
                  onRefresh: ds.refresh,
                  // CustomScrollView + slivers so product cards build lazily
                  // (only what's on screen) instead of all at once — this is
                  // what keeps scrolling smooth with a large inventory.
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats + Search + Filters header block
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              // Stats Row
                              Row(
                                children: ds.isLoaded
                                  ? [
                                      _statCard('Low Stock', totalLowStock.toString(), AppColors.warning),
                                      const SizedBox(width: 12),
                                      _statCard('Out of Stock', totalOutOfStock.toString(), AppColors.error),
                                    ]
                                  : const [
                                      InventoryStatSkeleton(),
                                      SizedBox(width: 12),
                                      InventoryStatSkeleton(),
                                    ],
                              ),
                              const SizedBox(height: 16),

                              // Search Field
                              TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search products by name or code...',
                                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight),
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.adminPrimary, size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.adminPrimary, width: 1),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Brand Filters — derived from the brands table (dynamic)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _filterChip('All', _selectedBrand == 'All'),
                                    ...ds.getAllBrands().map((b) =>
                                        _filterChip(b.name, _selectedBrand == b.name)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),

                      // Product List (lazy slivers)
                      if (!ds.isLoaded)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => const InventoryItemSkeleton(),
                              childCount: 5,
                            ),
                          ),
                        )
                      else if (products.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No products found',
                                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      else if (Responsive.isDesktop(context))
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 0,
                              childAspectRatio: 1.8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildProductListItem(products[index]),
                              childCount: products.length,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildProductListItem(products[index]),
                              childCount: products.length,
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/add-product'),
        backgroundColor: AppColors.adminPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _exportPDF(List<ProductModel> products) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Inventory Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Product', 'Brand', 'Category', 'Stock'],
            data: products.map((p) => [p.name, p.brand, p.category, p.stockLevel.toString()]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(-2, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedBrand = label);
        },
        selectedColor: AppColors.adminPrimary,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.adminPrimary : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildProductListItem(ProductModel product) {
    final color = _hexToColor(product.colorHex);

    // Stock bar styling
    final double stockPercentage = (product.stockLevel / 500).clamp(0.0, 1.0);
    Color stockColor = AppColors.success;
    if (product.stockLevel <= 0) {
      stockColor = AppColors.error;
    } else if (product.isLowStock) {
      stockColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(22),
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
          if (product.isLowStock)
            BoxShadow(
              color: stockColor.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
        border: product.isLowStock
            ? Border.all(color: stockColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: InkWell(
        onTap: () => context.push('/admin/edit-product/${product.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image or Color Swatch
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: product.imageUrl != null && product.imageUrl!.isNotEmpty ? Colors.white : color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.cover,
                              // Displayed at 50px — decode small to keep memory low
                              // and rendering fast (2x for high-DPI screens).
                              memCacheWidth: 100,
                              memCacheHeight: 100,
                              fadeInDuration: const Duration(milliseconds: 150),
                              placeholder: (context, url) => Container(color: color.withValues(alpha: 0.3)),
                              errorWidget: (context, url, error) =>
                                  Container(color: color, child: const Icon(Icons.error_outline, size: 20, color: Colors.white)),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                ),
                            ),
                            IconButton(
                              onPressed: () => _confirmDeleteProduct(product),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (product.isLowStock) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stockColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: stockColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.stockLevel <= 0 ? 'OUT OF STOCK' : 'LOW STOCK',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: stockColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.brand} • ${product.colorCode} - ${product.colorName}',
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
              
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Bucket sizes and stock
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Sizes',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: product.bucketSizes.map((size) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.adminPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.adminPrimary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                size,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.adminPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Stock Progress Bar
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Stock: ',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${product.stockLevel} units',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: product.stockLevel <= 0 ? AppColors.error : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stockPercentage,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Out of Stock Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: product.isOutOfStock
                      ? AppColors.error.withValues(alpha: 0.06)
                      : AppColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: product.isOutOfStock
                        ? AppColors.error.withValues(alpha: 0.2)
                        : AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      product.isOutOfStock
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: product.isOutOfStock ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.isOutOfStock ? 'Marked as Out of Stock' : 'In Stock',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: product.isOutOfStock ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: product.isOutOfStock,
                        onChanged: (val) async {
                          HapticFeedback.mediumImpact();
                          await ref.read(dataServiceProvider).toggleOutOfStock(product.id, val);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val
                                      ? '${product.name} marked as Out of Stock'
                                      : '${product.name} is now In Stock',
                                ),
                                backgroundColor: val ? AppColors.error : AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        activeColor: AppColors.error,
                        inactiveThumbColor: AppColors.success,
                        inactiveTrackColor: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Product?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete ${product.name}? This action cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(dataServiceProvider).deleteProduct(product.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} deleted'), 
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
