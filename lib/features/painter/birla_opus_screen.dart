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
import '../../services/cart_service.dart';

/// Birla Opus multi-level product selection screen.
///
/// Level 0: Main categories (Interior, Exterior, Wall Putty, Oil Paint, Alldry, Designer Finish, Allwood)
/// Level 1: Sub-categories (Luxury, Premium, Emulsion, Designer Finish) — only for Interior/Exterior/Oil Paint
/// Level 2: Product listing for the selected category + sub-category
///
/// Special cases:
///   - Wall Putty: shows putty image → 2 options (Packet / Custom Kg)
///   - Luxury, Designer Finish, Alldry, Allwood: skip sub-category, go directly to products
class BirlaOpusScreen extends ConsumerStatefulWidget {
  const BirlaOpusScreen({super.key});

  @override
  ConsumerState<BirlaOpusScreen> createState() => _BirlaOpusScreenState();
}

class _BirlaOpusScreenState extends ConsumerState<BirlaOpusScreen> {
  // Navigation state
  String? _selectedCategory; // Level 0 selection
  String? _selectedSubCategory; // Level 1 selection
  bool _showPuttyOptions = false; // Putty level 1 (Acrylic vs Wall Care)
  ProductModel? _selectedPuttyProduct; // Level 2 selection
  bool _showPuttyChoice = false; // Putty level 2 (Customize vs Fixed)
  bool _showPuttyPacket = false; // Level 3 (Fixed size selection)
  bool _showPuttyCustom = false; // Level 3 (Manual kg entry)

  final _customKgCtrl = TextEditingController();

  // UI Metadata mapping for known categories
  static final Map<String, Map<String, dynamic>> _categoryUIMetadata = {
    'Interior': {'icon': Icons.weekend_rounded, 'color': const Color(0xFF6366F1)},
    'Exterior': {'icon': Icons.house_rounded, 'color': const Color(0xFF10B981)},
    'Wall Putty': {'icon': Icons.grid_3x3_rounded, 'color': const Color(0xFFEAB308)},
    'Oil Paint': {'icon': Icons.format_paint_rounded, 'color': const Color(0xFFEF4444)},
    'Alldry': {'icon': Icons.water_drop_rounded, 'color': const Color(0xFF3B82F6)},
    'Designer Finish': {'icon': Icons.brush_rounded, 'color': const Color(0xFF8B5CF6)},
    'Allwood': {'icon': Icons.park_rounded, 'color': const Color(0xFFA16207)},
  };

  final Color _brandColor = AppColors.getBrandPrimary('Birla Opus');

  @override
  void dispose() {
    _customKgCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    setState(() {
      if (_showPuttyPacket || _showPuttyCustom) {
        _showPuttyPacket = false;
        _showPuttyCustom = false;
      } else if (_showPuttyChoice) {
        _showPuttyChoice = false;
      } else if (_showPuttyOptions) {
        _showPuttyOptions = false;
        _selectedCategory = null;
        _selectedPuttyProduct = null;
      } else if (_selectedSubCategory != null) {
        _selectedSubCategory = null;
      } else if (_selectedCategory != null) {
        _selectedCategory = null;
      } else {
        context.pop();
      }
    });
  }

  String get _currentTitle {
    if (_showPuttyPacket) return 'Select Packet Size';
    if (_showPuttyCustom) return 'Enter Custom Quantity';
    if (_showPuttyChoice) return _selectedPuttyProduct?.name ?? 'Wall Putty';
    if (_showPuttyOptions) return 'Wall Putty';
    if (_selectedSubCategory != null) return '$_selectedCategory › $_selectedSubCategory';
    if (_selectedCategory != null) return _selectedCategory!;
    return 'Birla Opus';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedCategory == null && !_showPuttyOptions,
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
          colors: [AppColors.birlaOpusGradientStart, AppColors.birlaOpusGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(-4, -4),
          ),
          BoxShadow(
            color: AppColors.birlaOpusGradientEnd.withValues(alpha: 0.5),
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
            Center(
              child: Image.network(
                'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus_big.png',
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Nature-Inspired Colors • Premium Quality',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
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
    // Putty Packet flow
    // Putty levels
    if (_showPuttyPacket) return _buildPuttyPacketOptions(key: const ValueKey('putty_packet'));
    if (_showPuttyCustom) return _buildPuttyCustomInput(key: const ValueKey('putty_custom'));
    if (_showPuttyChoice) return _buildPuttyChoiceSelection(key: const ValueKey('putty_choice'));
    if (_showPuttyOptions) return _buildPuttyProductSelection(key: const ValueKey('putty_product'));
    // Sub-category listing (Level 2)
    if (_selectedSubCategory != null) return _buildProductListing(key: const ValueKey('listing'));

    // Sub-category selection (Level 1)
    if (_selectedCategory != null) {
      final ds = ref.watch(dataServiceProvider);
      final subCatGroups = ds.getProductsGroupedBySubCategory('Birla Opus', _selectedCategory!);
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
        itemBuilder: (_, __) => const BrandCardSkeleton(),
      );
    }

    final availableCategories = ds.getCategoriesForBrand('Birla Opus').where((c) => c != 'None' && c.isNotEmpty).toList();

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
                Icon(Icons.category_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No categories found', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Check back later for products', style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 13)),
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
            'Tap a category to explore products',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...availableCategories.map((catName) {
            final ui = _categoryUIMetadata[catName] ?? {
              'icon': Icons.auto_awesome_mosaic_rounded, 
              'color': const Color(0xFF64748B) // Slate/Fallback color
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
    final productCount = ds.getProductsByCategory('Birla Opus', name).length;

    return GestureDetector(
      onTap: () {
        if (PlatformSupport.supportsHaptics) HapticFeedback.lightImpact();
        setState(() {
          _selectedCategory = name;
          if (name == 'Wall Putty') {
            _showPuttyOptions = true;
          }
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
                  Text('$productCount products available', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
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
    final subCatGroups = ds.getProductsGroupedBySubCategory('Birla Opus', _selectedCategory!);
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
      'icon': Icons.palette_rounded,
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
              child: Icon(Icons.palette_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('$count products', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
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
      products = ds.getProductsByCategory('Birla Opus', category).where(
        (p) => p.subCategory.toLowerCase() == _selectedSubCategory!.toLowerCase(),
      ).toList();
    } else {
      products = ds.getProductsByCategory('Birla Opus', category);
    }

    if (products.isEmpty && !ds.isLoaded) {
       return GridView.builder(
        key: key,
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isDesktop(context) ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const InventoryItemSkeleton(),
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
                Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textLight),
                const SizedBox(height: 16),
                Text('No products available yet', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('Products will appear here once added', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight)),
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
          childAspectRatio: 0.7,
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
                            style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
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
                            style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
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
                            backgroundColor: _brandColor.withOpacity(0.1),
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



  // ─── PUTTY FLOW ───────────────────────────────────────────────
  Widget _buildPuttyProductSelection({Key? key}) {
    final ds = ref.watch(dataServiceProvider);
    final puttyProducts = ds.getProductsByCategory('Birla Opus', 'Wall Putty');

    return ListView(
      key: key,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select Putty Type',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        ...puttyProducts.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _puttyOptionCard(
              p.name,
              'High quality Birla Opus Putty',
              Icons.grid_3x3_rounded,
              const Color(0xFFEAB308),
              () => setState(() {
                _selectedPuttyProduct = p;
                _showPuttyChoice = true;
              }),
              imageUrl: p.imageUrl,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPuttyChoiceSelection({Key? key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'How would you like to order?',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        _puttyOptionCard(
          'Customize Your Order',
          'Enter custom quantity in kilograms',
          Icons.edit_rounded,
          const Color(0xFF6366F1),
          () {
            if (PlatformSupport.supportsHaptics) HapticFeedback.lightImpact();
            setState(() => _showPuttyCustom = true);
          },
        ),
        const SizedBox(height: 12),
        _puttyOptionCard(
          'Fixed Packets',
          'Choose from standard 30kg or 60kg packets',
          Icons.inventory_2_rounded,
          const Color(0xFF10B981),
          () {
            if (PlatformSupport.supportsHaptics) HapticFeedback.lightImpact();
            setState(() => _showPuttyPacket = true);
          },
        ),
      ],
    );
  }

  Widget _puttyOptionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {String? imageUrl}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ProductImage(
                productId: '', 
                imageUrl: imageUrl,
                brand: 'Birla Opus',
                size: 64,
                borderRadius: 14,
              )
            else
              Container(
                width: 64,
                height: 64,
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
                  Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  // ─── PUTTY PACKET SELECTION ───────────────────────────────────
  Widget _buildPuttyPacketOptions({Key? key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select Packet Size',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a standard packet size to order',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _packetSizeCard('30kg', 'Standard Pack', Icons.inventory_2_rounded),
        const SizedBox(height: 16),
        _packetSizeCard('60kg', 'Large Pack', Icons.all_inbox_rounded),
      ],
    );
  }

  Widget _packetSizeCard(String size, String label, IconData icon) {
    return GestureDetector(
      onTap: () => _navigateToPuttyOrder(size, 1),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _brandColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: _brandColor.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brandColor.withValues(alpha: 0.15), _brandColor.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _brandColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(size, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _brandColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Order', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PUTTY CUSTOM KG INPUT ────────────────────────────────────
  Widget _buildPuttyCustomInput({Key? key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Enter Custom Quantity',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Type the number of kilograms you need',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _customKgCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textLight),
                  suffixText: 'KG',
                  suffixStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _brandColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _brandColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final kg = int.tryParse(_customKgCtrl.text) ?? 0;
                    if (kg < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid quantity')),
                      );
                      return;
                    }
                    _navigateToPuttyOrder('1kg', kg);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: _brandColor.withValues(alpha: 0.4),
                  ),
                  child: Text('Proceed to Order', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToPuttyOrder(String size, int qty) {
    final product = _selectedPuttyProduct;
    if (product != null) {
      final isChoice = _showPuttyCustom;
      final uri = Uri(
        path: '/painter/order-item/${product.id}',
        queryParameters: {
          'size': size,
          'qty': qty.toString(),
          'canCustomize': isChoice ? 'true' : 'false',
        },
      );
      context.push(uri.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No putty products available')),
      );
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
