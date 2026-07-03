import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/cart_service.dart';
import '../../services/data_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';
import '../../core/widgets/clay_card.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final total = cartNotifier.totalAmount;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('My Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              onPressed: () => cartNotifier.clear(),
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _buildCartItem(context, ref, item);
                    },
                  ),
                ),
                _buildSummary(context, ref, total),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some paints to get started',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Go Shopping', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ProductImage(
            imageUrl: item.productImageUrl,
            productId: item.productId,
            brand: '', // Brand not strictly needed here for display
            size: 60,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.bucketSize}${item.shadeCode != null ? ' • ${item.shadeCode}' : ''}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _qtyBtn(Icons.remove_rounded, () {
                ref.read(cartProvider.notifier).updateQuantity(item.productId, item.bucketSize, item.quantity - 1, shadeCode: item.shadeCode);
              }),
              SizedBox(
                width: 30,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
              _qtyBtn(Icons.add_rounded, () {
                ref.read(cartProvider.notifier).updateQuantity(item.productId, item.bucketSize, item.quantity + 1, shadeCode: item.shadeCode);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref, double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Total',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Final prices will be set by admin in the bill.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _handleCheckout(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                child: Text(
                  'Request Bill',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCheckout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final user = ref.read(authProvider).user;
    if (user == null || cart.isEmpty) return;

    // Require site location for checkout
    final siteLocationCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Confirm & Checkout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your site/delivery address to place the order.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: siteLocationCtrl,
                maxLines: 2,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Site / Delivery Address *',
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                if (siteLocationCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter your site address')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Place Order', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      // Group items by brand (actually for now we just create one order per brand or one big order)
      // The user requested a general "Add to Cart", so we'll create one order with all items.
      // Note: OrderModel has a 'brand' field. If items are mixed, we can use 'Mixed' or the first item's brand.
      final brand = cart.first.productId.contains('tool') ? 'Tools' : 'Asian Paints'; // Simplified logic

      final orderItems = cart.map((item) {
        final product = ref.read(dataServiceProvider).getProductById(item.productId);
        return OrderItemModel(
          productId: item.productId,
          productName: item.productName,
          productImageUrl: item.productImageUrl,
          bucketSize: item.bucketSize,
          shadeCode: item.shadeCode,
          quantity: item.quantity,
          unitPrice: item.price,
          totalPrice: item.total,
          colorCode: product?.colorCode ?? '',
          colorName: product?.colorName ?? '',
          colorHex: product?.colorHex ?? '#FFFFFF',
        );
      }).toList();

      final order = OrderModel(
        id: '', // Will be set by service
        painterId: user.id,
        painterName: user.name,
        painterPhone: user.phone,
        brand: brand,
        items: orderItems,
        totalAmount: ref.read(cartProvider.notifier).totalAmount,
        status: 'pending_bill',
        paymentMethod: 'udhaari',
        paymentStatus: 'pending',
        siteLocation: siteLocationCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(dataServiceProvider).placeOrder(order);
      
      ref.read(cartProvider.notifier).clear();
      
      if (context.mounted) {
        context.go('/painter/orders');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order requested successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
