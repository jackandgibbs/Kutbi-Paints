import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';

class BrandDashboardScreen extends ConsumerStatefulWidget {
  final String brand;
  const BrandDashboardScreen({super.key, required this.brand});

  @override
  ConsumerState<BrandDashboardScreen> createState() =>
      _BrandDashboardScreenState();
}

class _BrandDashboardScreenState extends ConsumerState<BrandDashboardScreen> {
  late String _selectedBrand;
  String? _selectedCategory;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.brand;
    _initCategories();
  }

  void _initCategories() {
    final ds = ref.read(dataServiceProvider);
    final categories = ds.getCategoriesForBrand(_selectedBrand);
    if (categories.isNotEmpty) {
      _selectedCategory = categories.first;
    } else {
      _selectedCategory = null;
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    // Scroll back to top when switching categories
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final brandColor = AppColors.getBrandPrimary(_selectedBrand);
    
    if (!ds.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: brandColor),
        ),
      );
    }

    final categories = ds.getCategoriesForBrand(_selectedBrand);
    
    // Reactively ensure we have a category selected if data just loaded
    final effectiveCategory = _selectedCategory ?? (categories.isNotEmpty ? categories.first : null);
    
    final groupedProducts = effectiveCategory != null 
        ? ds.getProductsGroupedBySubCategory(_selectedBrand, effectiveCategory)
        : <String, List<ProductModel>>{};

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          // ─── Top Header (Brand Switcher) ────────────────────────
          _buildBrandHeader(brandColor),

          // ─── Category Tabs ─────────────────────────────────────
          if (categories.isNotEmpty)
            _buildCategoryTabs(categories, effectiveCategory, brandColor),

          // ─── Products List (Grouped by Sub-Category) ───────────
          Expanded(
            child: effectiveCategory == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No products available for this brand',
                          style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: groupedProducts.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubCategoryHeader(entry.key, brandColor),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: entry.value.length,
                            itemBuilder: (context, index) {
                              return _productCard(entry.value[index], brandColor);
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(Color brandColor) {
    final brands = ['Asian Paints', 'Berger', 'Birla Opus'];
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
      color: brandColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                ),
                Text(
                  'Explore Brands',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: brands.map((b) {
                final isSelected = b == _selectedBrand;
                return GestureDetector(
                  onTap: () {
                    if (b == 'Birla Opus') {
                      context.pushReplacement('/painter/birla-opus');
                      return;
                    }
                    if (b == 'Berger') {
                      context.pushReplacement('/painter/berger');
                      return;
                    }
                    if (b == 'Asian Paints') {
                      context.pushReplacement('/painter/asian-paints');
                      return;
                    }
                    setState(() {
                      _selectedBrand = b;
                      _initCategories();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Text(
                      b,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? brandColor : Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCategoryTabs(List<String> labels, String? activeCategory, Color brandColor) {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final label = labels[index];
          final isSelected = label == activeCategory;
          return GestureDetector(
            onTap: () => _onCategorySelected(label),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? brandColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? brandColor : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubCategoryHeader(String title, Color brandColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: brandColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          'View All',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: brandColor,
          ),
        ),
      ],
    );
  }

  Widget _productCard(ProductModel product, Color brandColor) {
    return GestureDetector(
      onTap: () => context.push('/painter/order-item/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: product.imageUrl != null && product.imageUrl!.isNotEmpty 
                      ? null 
                      : _hexToColor(product.colorHex),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  image: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? null
                    : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      product.colorCode.isNotEmpty ? product.colorCode : product.name,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
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
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'From ₹${product.prices.values.first.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: brandColor,
                        ),
                      ),
                      Icon(Icons.add_circle_outline_rounded, color: brandColor, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
