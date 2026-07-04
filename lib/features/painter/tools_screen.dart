import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_support.dart';
import '../../core/utils/responsive.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';
import '../shared/widgets/skeleton_loaders.dart';
import '../shared/widgets/product_image.dart';

/// Tools multi-level product selection screen.
///
/// Level 0: Main categories
/// Level 1: Sub-categories 
/// Level 2: Product listing for the selected category + sub-category
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  // Navigation state
  String? _selectedCategory; // Level 0 selection
  String? _selectedSubCategory; // Level 1 selection

  // UI Metadata mapping for known categories
  static final Map<String, Map<String, dynamic>> _categoryUIMetadata = {
    'Brushes': {'icon': Icons.brush_rounded, 'color': const Color(0xFF6366F1)},
    'Rollers': {'icon': Icons.format_paint_rounded, 'color': const Color(0xFF10B981)},
    'Sandpaper': {'icon': Icons.grid_4x4_rounded, 'color': const Color(0xFFEAB308)},
    'Putty Knife': {'icon': Icons.construction_rounded, 'color': const Color(0xFFEF4444)},
    'Tapes': {'icon': Icons.format_line_spacing_rounded, 'color': const Color(0xFF3B82F6)},
    'Spray Guns': {'icon': Icons.air_rounded, 'color': const Color(0xFF8B5CF6)},
    'Mixing Tools': {'icon': Icons.blender_rounded, 'color': const Color(0xFFA16207)},
    'Safety Equipment': {'icon': Icons.health_and_safety_rounded, 'color': const Color(0xFF059669)},
    'Drop Cloths': {'icon': Icons.layers_rounded, 'color': const Color(0xFF0EA5E9)},
    'Ladders & Scaffolding': {'icon': Icons.stairs_rounded, 'color': const Color(0xFFD946EF)},
  };

  final Color _brandColor = AppColors.getBrandPrimary('Tools');

  void _goBack() {
    setState(() {
      if (_selectedSubCategory != null) {
        _selectedSubCategory = null;
      } else if (_selectedCategory != null) {
        _selectedCategory = null;
      } else {
        context.pop();
      }
    });
  }

  String get _currentTitle {
    if (_selectedSubCategory != null) return '$_selectedCategory › $_selectedSubCategory';
    if (_selectedCategory != null) return _selectedCategory!;
    return 'Tools & Accessories';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.toolsGradientStart, AppColors.toolsGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(-4, -4),
          ),
          BoxShadow(
            color: AppColors.toolsGradientEnd.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Text(
                    _currentTitle,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCategory == null) ...[
            const SizedBox(height: 16),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.construction_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Professional Painting Tools & Accessories',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── CONTENT ROUTER ────────────────────────────────────────────
  Widget _buildContent() {
    if (PlatformSupport.isDesktop) {
      return _getCurrentView();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: _getCurrentView(),
    );
  }

  Widget _getCurrentView() {
    // Sub-category listing (Level 2)
    if (_selectedSubCategory != null) return _buildProductListing(key: const ValueKey('listing'));

    // Sub-category selection (Level 1)
    if (_selectedCategory != null) {
      final ds = ref.watch(dataServiceProvider);
      final subCatGroups = ds.getProductsGroupedBySubCategory('Tools', _selectedCategory!);
      final subCats = subCatGroups.keys.where((s) => s.isNotEmpty && s != 'None').toList();
      
      // If there's only one sub-category or it's empty, go directly to product listing
      if (subCats.isEmpty || (subCats.length == 1 && (subCats.first.isEmpty || subCats.first == _selectedCategory))) {
        return _buildProductListing(key: const ValueKey('listing_direct'));
      }
      return _buildSubCategorySelection(key: const ValueKey('subcat'));
    }

    // Main categories (Level 0)
    return _buildMainCategories(key: const ValueKey('main'));
  }

  // ─── LEVEL 0: Main Categories ──────────────────────────────────
  Widget _buildMainCategories({Key? key}) {
    final ds = ref.watch(dataServiceProvider);
    
    if (!ds.isLoaded) {
      return ListView.builder(
        key: key,
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (_, _) => const BrandCardSkeleton(),
      );
    }

    final availableCategories = ds.getCategoriesForBrand('Tools').where((c) => c != 'None' && c.isNotEmpty).toList();

    if (availableCategories.isEmpty) {
      return RefreshIndicator(
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.construction_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No tools available yet', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Tools will appear once added', style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Select Category',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a category to explore tools',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...availableCategories.map((catName) {
            final ui = _categoryUIMetadata[catName] ?? {
              'icon': Icons.build_rounded, 
              'color': const Color(0xFF64748B)
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _categoryCard(
                catName,
                ui['icon'] as IconData,
                ui['color'] as Color,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryCard(String name, IconData icon, Color color) {
    final ds = ref.watch(dataServiceProvider);
    final productCount = ds.getProductsByCategory('Tools', name).length;

    return GestureDetector(
      onTap: () {
        if (PlatformSupport.supportsHaptics) HapticFeedback.lightImpact();
        setState(() {
          _selectedCategory = name;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('$productCount items available', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  // ─── LEVEL 1: Sub-Category Selection ──────────────────────────
  Widget _buildSubCategorySelection({Key? key}) {
    final ds = ref.watch(dataServiceProvider);
    final subCatGroups = ds.getProductsGroupedBySubCategory('Tools', _selectedCategory!);
    final subCategories = subCatGroups.keys.where((s) => s.isNotEmpty && s != 'None').toList();

    return RefreshIndicator(
      key: key,
      onRefresh: ds.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Select Sub-Category',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a type under $_selectedCategory',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...subCategories.map((sub) {
            final count = subCatGroups[sub]?.length ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _subCategoryCard(sub, count),
            );
          }),
        ],
      ),
    );
  }

  Widget _subCategoryCard(String name, int count) {
    final uiMeta = _categoryUIMetadata[name] ?? {
      'icon': Icons.build_rounded,
      'color': _brandColor,
    };
    final color = uiMeta['color'] as Color;

    return GestureDetector(
      onTap: () {
        if (PlatformSupport.supportsHaptics) HapticFeedback.lightImpact();
        setState(() => _selectedSubCategory = name);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.build_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('$count items', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // ─── LEVEL 2: Product Listing ─────────────────────────────────
  Widget _buildProductListing({Key? key}) {
    final ds = ref.watch(dataServiceProvider);
    final category = _selectedCategory!;

    List<ProductModel> products;
    if (_selectedSubCategory != null) {
      products = ds.getProductsByCategory('Tools', category).where(
        (p) => p.subCategory.toLowerCase() == _selectedSubCategory!.toLowerCase(),
      ).toList();
    } else {
      products = ds.getProductsByCategory('Tools', category);
    }

    if (products.isEmpty && !ds.isLoaded) {
       return GridView.builder(
        key: key,
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isDesktop(context) ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const InventoryItemSkeleton(),
      );
    }

    if (products.isEmpty) {
      return RefreshIndicator(
        key: key,
        onRefresh: ds.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - 150,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.construction_outlined, size: 64, color: AppColors.textLight),
                const SizedBox(height: 16),
                Text('No tools available yet', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('Tools will appear here once added', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      key: key,
      onRefresh: ds.refresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isDesktop(context) ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(child: _productCard(products[index]));
        },
      ),
    );
  }

  Widget _productCard(ProductModel product) {
    final isOutOfStock = product.isEffectivelyOutOfStock;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => context.push('/painter/order-item/${product.id}'),
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ProductImage(
                      productId: product.id,
                      imageUrl: product.imageUrl,
                      brand: product.brand,
                      size: double.infinity,
                      borderRadius: 20,
                      heroTag: 'product-${product.id}',
                    ),
                    // Stock badge
                    if (isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'OUT OF STOCK',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else if (product.isLowStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${product.stockLevel} left',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    if (isOutOfStock)
                      Text(
                        'Currently Unavailable',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.error),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push('/painter/order-item/${product.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandColor.withValues(alpha: 0.1),
                            foregroundColor: _brandColor,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Order Now',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
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


}
