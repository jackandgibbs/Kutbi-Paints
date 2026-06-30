import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';
import '../../core/widgets/clay_card.dart';
import '../shared/widgets/product_image.dart';

class OrderItemScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? initialSize;
  final int? initialQty;
  final bool canCustomize;

  const OrderItemScreen({
    super.key, 
    required this.productId,
    this.initialSize,
    this.initialQty,
    this.canCustomize = true,
  });

  @override
  ConsumerState<OrderItemScreen> createState() => _OrderItemScreenState();
}

class _OrderItemScreenState extends ConsumerState<OrderItemScreen> with TickerProviderStateMixin {
  late final TextEditingController _qtyCtrl;
  String? _selectedSize;
  bool _isCustomQty = false;

  late final AnimationController _staggerController;
  late final List<Animation<double>> _staggerAnimations;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.initialQty?.toString() ?? '1');
    _selectedSize = widget.initialSize;
    if (widget.initialQty != null) {
      _isCustomQty = true;
    }

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _staggerAnimations = List.generate(5, (index) {
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
      );
    });

    _staggerController.forward();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final product = ds.getProductById(widget.productId);
    
    if (product == null) {
      return Scaffold(body: Center(child: Text('Product not found')));
    }

    _selectedSize ??= product.availableBucketSizes.first;
    final brandColor = AppColors.getBrandPrimary(product.brand);
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
        ),
        title: Text(
          'Customize Order',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Product Card ──────────────────────────────────────
            FadeTransition(
              opacity: _staggerAnimations[0],
              child: _buildProductHeader(product, brandColor),
            ),
            const SizedBox(height: 30),

            // ─── Size Selection ────────────────────────────────────
            if (!(product.category.toLowerCase().contains('putty') && _isCustomQty)) ...[
              FadeTransition(
                opacity: _staggerAnimations[1],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Bucket Size', style: _sectionStyle()),
                    const SizedBox(height: 12),
                    _buildSizePicker(product, brandColor),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],

            // ─── Quantity Selection ────────────────────────────────
            FadeTransition(
              opacity: _staggerAnimations[2],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantity', style: _sectionStyle()),
                      if (widget.canCustomize)
                        TextButton(
                          onPressed: () => setState(() => _isCustomQty = !_isCustomQty),
                          child: Text(_isCustomQty ? 'Use Fixed' : 'Custom Amount', 
                            style: GoogleFonts.poppins(color: brandColor, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isCustomQty ? _buildCustomQtyInput(brandColor, product) : _buildFixedQtyPicker(brandColor),
                ],
              ),
            ),
            const SizedBox(height: 40),

            FadeTransition(
              opacity: _staggerAnimations[3],
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: brandColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: brandColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin will provide the final bill after you place the order.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            FadeTransition(
              opacity: _staggerAnimations[4],
              child: GestureDetector(
                onTap: () => _proceedToCheckout(product, qty),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            brandColor.withValues(alpha: 0.8),
                            brandColor.withValues(alpha: 0.6),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.15),
                            blurRadius: 1,
                            spreadRadius: 0,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Proceed to Order',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader(ProductModel product, Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          ProductImage(
            productId: product.id,
            imageUrl: product.imageUrl,
            brand: product.brand,
            size: 80,
            borderRadius: 16,
            heroTag: 'product-${product.id}',
          ),

          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${product.colorCode} • ${product.brand}', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: brandColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(product.subCategory, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: brandColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePicker(ProductModel product, Color brandColor) {
    final sizes = List<String>.from(product.availableBucketSizes);
    if (_selectedSize != null && !sizes.contains(_selectedSize)) {
      sizes.insert(0, _selectedSize!);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sizes.map((size) {
        final isSelected = size == _selectedSize;
        return AnimatedClayCard(
          onTap: () => setState(() => _selectedSize = size),
          borderRadius: 16,
          surfaceColor: isSelected ? brandColor : AppColors.clayBase,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(size, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
        );
      }).toList(),
    );
  }

  Widget _buildFixedQtyPicker(Color brandColor) {
    final qtys = [1, 4, 10, 20];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: qtys.map((q) {
        final isSelected = _qtyCtrl.text == q.toString();
        return AnimatedClayCard(
          onTap: () => setState(() => _qtyCtrl.text = q.toString()),
          borderRadius: 20,
          surfaceColor: isSelected ? brandColor : AppColors.clayBase,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 70,
            height: 70,
            child: Center(
              child: Text('$q', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textPrimary)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomQtyInput(Color brandColor, ProductModel product) {
    final isPutty = product.category.toLowerCase().contains('putty');
    return TextField(
      controller: _qtyCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Enter quantity',
        prefixIcon: Icon(Icons.shopping_basket_rounded, color: brandColor),
        suffixText: isPutty ? 'KG' : 'Buckets',
        suffixStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }



  TextStyle _sectionStyle() => GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  void _proceedToCheckout(ProductModel product, int qty) {
    if (qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid quantity')));
      return;
    }
    
    // In a real app, we might add this to a basket.
    // To follow the "Selecting one leads to order page" plan from the sketch,
    // we navigate to the final OrderForm with this item pre-filled or restricted.
    
    // Redirection to OrderForm with pre-selected item via query params
    final uri = Uri(
      path: '/painter/order/${Uri.encodeComponent(product.brand)}',
      queryParameters: {
        'productId': product.id,
        'size': _selectedSize,
        'qty': _qtyCtrl.text,
      },
    );
    context.push(uri.toString());
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
