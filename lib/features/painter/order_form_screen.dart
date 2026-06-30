import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_support.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../shared/widgets/product_image.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final String brand;
  final String? initialProductId;
  final String? initialSize;
  final int? initialQty;

  const OrderFormScreen({
    super.key,
    required this.brand,
    this.initialProductId,
    this.initialSize,
    this.initialQty,
  });

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _siteLocationCtrl = TextEditingController();

  // Order items
  final List<_OrderItemEntry> _items = [];

  bool _isFetchingLocation = false;

  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.initialProductId != null) {
      final ds = ref.read(dataServiceProvider);
      final product = ds.getProductById(widget.initialProductId!);
      if (product != null) {
        final entry = _OrderItemEntry();
        entry.selectedProduct = product;
        entry.selectedSize =
            widget.initialSize ?? product.availableBucketSizes.first;
        if (widget.initialQty != null) {
          entry.qtyCtrl.text = widget.initialQty.toString();
        }
        _items.add(entry);
      } else {
        _addItem();
      }
    } else {
      _addItem();
    }

    _staggerController.forward();
  }

  @override
  void dispose() {
    _siteLocationCtrl.dispose();
    _staggerController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_OrderItemEntry());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  double _calculateTotal() {
    return 0; // Prices are calculated by admin after order is placed
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        final turnOn = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Location Disabled',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Please turn on your device location to fetch your current address.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getBrandPrimary(widget.brand),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Settings',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

        if (turnOn == true) {
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!PlatformSupport.supportsReverseGeocoding) {
        _siteLocationCtrl.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        return;
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty)
          addressParts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty)
          addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty)
          addressParts.add(place.locality!);
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty)
          addressParts.add(place.administrativeArea!);
        if (place.postalCode != null && place.postalCode!.isNotEmpty)
          addressParts.add(place.postalCode!);

        final address = addressParts.join(', ');
        _siteLocationCtrl.text = address;
      } else {
        throw 'No address found for this location.';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Defer to next frame to avoid mouse_tracker assertion on desktop
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Order',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to place this order?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getBrandPrimary(widget.brand),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Yes, Place Order',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ds = ref.read(dataServiceProvider);
    final user = ref.read(authProvider).user!;
    final isGold = user.isGold;

    final orderItems = <OrderItemModel>[];
    for (final item in _items) {
      if (item.selectedProduct == null || item.selectedSize == null) continue;
      final prices = isGold
          ? (item.selectedProduct!.goldPrices ?? item.selectedProduct!.prices)
          : item.selectedProduct!.prices;
      double basePrice = prices[item.selectedSize!] ?? 0;

      // Fallback for Wall Putty if 1kg price is missing
      final isPutty =
          item.selectedProduct!.category.toLowerCase().contains('putty') ||
          item.selectedProduct!.name.toLowerCase().contains('putty');

      if (basePrice == 0 && isPutty && item.selectedSize == '1kg') {
        final p30 = prices['30kg'] ?? 450.0;
        basePrice = p30 / 30;
      }

      // finalPrice calculation removed as pricing is admin-side only
      final qty = int.tryParse(item.qtyCtrl.text) ?? 0;

      orderItems.add(
        OrderItemModel(
          productId: item.selectedProduct!.id,
          productName: item.selectedProduct!.name,
          colorCode: item.selectedProduct!.colorCode,
          colorName: item.selectedProduct!.colorName,
          colorHex: item.selectedProduct!.colorHex,
          quantity: qty,
          bucketSize: item.selectedSize!,
          unitPrice: 0,
          totalPrice: 0,
          productImageUrl: item.selectedProduct!.imageUrl,
          shadeCode: item.shadeCodeCtrl.text.trim().isEmpty
              ? null
              : item.shadeCodeCtrl.text.trim(),
        ),
      );
    }

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final order = OrderModel(
      id: '',
      painterId: user.id,
      painterName: user.name,
      painterPhone: user.phone,
      brand: widget.brand,
      items: orderItems,
      siteLocation: _siteLocationCtrl.text.trim(),
      paymentMethod: 'udhaari',
      totalAmount: _calculateTotal(),
      status: 'pending_bill',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ds.placeOrder(order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'Order Submitted!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your order has been submitted. The admin will review and send you a bill shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/painter');
                },
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final allProducts = ds.getAllProducts();
    final brandColor = AppColors.getBrandPrimary(widget.brand);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text(
          'Place Order - ${widget.brand}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Site Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionHeader('📍 Site Location'),
                    TextButton.icon(
                      onPressed: _isFetchingLocation
                          ? null
                          : _fetchCurrentLocation,
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              color: brandColor,
                              size: 18,
                            ),
                      label: Text(
                        'Use Current',
                        style: GoogleFonts.poppins(
                          color: _isFetchingLocation
                              ? AppColors.textSecondary
                              : brandColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (!PlatformSupport.supportsReverseGeocoding)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Windows currently fills this field with GPS coordinates because desktop address lookup is not configured yet.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _siteLocationCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter site address or location',
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Site location is required' : null,
                ),
                const SizedBox(height: 24),

                // Order Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionHeader('🎨 Order Items'),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: Icon(Icons.add_circle_rounded, color: brandColor),
                      label: Text(
                        'Add Item',
                        style: GoogleFonts.poppins(
                          color: brandColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...List.generate(_items.length, (i) {
                  return _buildItemCard(i, allProducts, brandColor);
                }),

                const SizedBox(height: 24),

                // Note
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: brandColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: brandColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Admin will bill your order',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: brandColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prices are not shown upfront. Once the admin reviews and generates the bill, you will be notified to confirm and pay.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Place Order',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _openProductSearch(
    BuildContext context,
    _OrderItemEntry item,
    List<ProductModel> products,
    FormFieldState<ProductModel> state,
  ) async {
    // Defer to next frame to avoid mouse_tracker assertion on desktop
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final selected = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductSearchSheet(products: products),
    );

    if (selected != null) {
      setState(() {
        item.selectedProduct = selected;
        item.selectedSize = null;
      });
      state.didChange(selected);
    }
  }

  Widget _buildItemCard(
    int index,
    List<ProductModel> products,
    Color brandColor,
  ) {
    final item = _items[index];

    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOut,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Item ${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: brandColor,
                    ),
                  ),
                  if (_items.length > 1)
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(
                        Icons.remove_circle_rounded,
                        color: AppColors.error,
                      ),
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Product dropdown
              (widget.initialProductId != null && index == 0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.palette_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.selectedProduct != null
                                  ? _productLabel(item.selectedProduct!)
                                  : 'Product',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : FormField<ProductModel>(
                      initialValue: item.selectedProduct,
                      validator: (v) => item.selectedProduct == null
                          ? 'Select a product'
                          : null,
                      builder: (state) {
                        return InkWell(
                          onTap: () {
                            _openProductSearch(context, item, products, state);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Select Product / Color',
                              prefixIcon: const Icon(Icons.palette_rounded),
                              errorText: state.errorText,
                            ),
                            isEmpty: item.selectedProduct == null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: item.selectedProduct == null
                                      ? const SizedBox.shrink()
                                      : Row(
                                          children: [
                                            ProductImage(
                                              productId:
                                                  item.selectedProduct!.id,
                                              imageUrl: item
                                                  .selectedProduct!
                                                  .imageUrl,
                                              brand:
                                                  item.selectedProduct!.brand,
                                              size: 24,
                                              borderRadius: 6,
                                              heroTag:
                                                  index == 0 &&
                                                      widget.initialProductId !=
                                                          null
                                                  ? 'product-${item.selectedProduct!.id}'
                                                  : null,
                                            ),

                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _productLabel(
                                                  item.selectedProduct!,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 12),

              // Bucket Size (full width)
              (widget.initialSize == '1kg' && index == 0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.straighten_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '1kg (Current)',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: item.selectedSize,
                      decoration: const InputDecoration(
                        labelText: 'Bucket Size',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                      items: () {
                        final sizes = List<String>.from(
                          _getBucketSizes(item.selectedProduct),
                        );
                        if (item.selectedSize != null &&
                            !sizes.contains(item.selectedSize)) {
                          sizes.insert(0, item.selectedSize!);
                        }
                        return sizes
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList();
                      }(),
                      onChanged: (v) => setState(() => item.selectedSize = v),
                      validator: (v) => v == null ? 'Select size' : null,
                    ),
              const SizedBox(height: 12),

              // Quantity (full width)
              TextFormField(
                controller: item.qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final qty = int.tryParse(v);
                  if (qty == null || qty < 1) return 'Min 1';
                  if (item.selectedProduct != null) {
                    final minQty = item.selectedProduct!.minQuantity;
                    if (minQty > 1 && qty < minQty) {
                      return 'Minimum qty is $minQty';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Color Shade Code
              if (_requiresColorShade(item.selectedProduct)) ...[
                TextFormField(
                  controller: item.shadeCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Color Shade Code',
                    hintText: 'e.g., L103, X456',
                    prefixIcon: Icon(Icons.format_color_fill_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
              ],

              // Status note instead of price
              if (item.selectedProduct != null &&
                  item.selectedSize != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Size: ${item.selectedSize}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (item.shadeCodeCtrl.text.trim().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SHADE: ${item.shadeCodeCtrl.text.trim().toUpperCase()}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: brandColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Qty: x${item.qtyCtrl.text}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasValue(String s) {
    final v = s.trim().toLowerCase();
    return v.isNotEmpty &&
        v != '-' &&
        v != '--' &&
        v != 'n/a' &&
        v != 'na' &&
        v != 'none';
  }

  String _productLabel(ProductModel p) {
    final hasCode = _hasValue(p.colorCode);
    final hasName = _hasValue(p.colorName);
    if (hasCode && hasName)
      return '${p.colorCode.trim()} - ${p.colorName.trim()}';
    if (hasCode) return '${p.name} (${p.colorCode.trim()})';
    if (hasName) return '${p.name} - ${p.colorName.trim()}';
    return p.name.isNotEmpty ? p.name : 'Unnamed Product';
  }

  bool _requiresColorShade(ProductModel? p) {
    if (p == null) return true;
    return p.hasColorShade;
  }

  List<String> _getBucketSizes(ProductModel? p) {
    if (p == null) return ['1L', '4L', '10L', '20L'];

    // First try the product's configured bucket sizes
    if (p.bucketSizes.isNotEmpty) return p.bucketSizes;
    if (p.prices.isNotEmpty) return p.prices.keys.toList();

    // Intelligent fallbacks using the product's unit
    final unit = p.unit;
    final cat = p.category.toLowerCase();
    final name = p.name.toLowerCase();

    if (cat.contains('putty') || name.contains('putty')) {
      return ['1KG', '30KG', '60KG'];
    }

    return ['1$unit', '4$unit', '10$unit', '20$unit'];
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final List<ProductModel> products;

  const _ProductSearchSheet({required this.products});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  String _searchQuery = '';
  String _selectedBrand = 'Asian Paints';
  late List<ProductModel> _filteredProducts;

  static const _brands = ['Asian Paints', 'Berger', 'Birla Opus', 'Tools'];

  @override
  void initState() {
    super.initState();
    _filteredProducts = _getFiltered();
  }

  List<ProductModel> _getFiltered() {
    final q = _searchQuery.toLowerCase();
    return widget.products.where((p) {
      final matchBrand = p.brand == _selectedBrand;
      if (!matchBrand) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.colorCode.toLowerCase().contains(q) ||
          p.colorName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.subCategory.toLowerCase().contains(q);
    }).toList();
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredProducts = _getFiltered();
    });
  }

  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = brand;
      _filteredProducts = _getFiltered();
    });
  }

  bool _hasValue(String s) {
    final v = s.trim().toLowerCase();
    return v.isNotEmpty &&
        v != '-' &&
        v != '--' &&
        v != 'n/a' &&
        v != 'na' &&
        v != 'none';
  }

  String _productLabel(ProductModel p) {
    final hasCode = _hasValue(p.colorCode);
    final hasName = _hasValue(p.colorName);
    if (hasCode && hasName)
      return '${p.colorCode.trim()} - ${p.colorName.trim()}';
    if (hasCode) return '${p.name} (${p.colorCode.trim()})';
    if (hasName) return '${p.name} - ${p.colorName.trim()}';
    return p.name.isNotEmpty ? p.name : 'Unnamed Product';
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  // Group products by category
  Map<String, List<ProductModel>> _groupByCategory(
    List<ProductModel> products,
  ) {
    final map = <String, List<ProductModel>>{};
    for (final p in products) {
      final cat = p.category.isNotEmpty ? p.category : 'Other';
      map.putIfAbsent(cat, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory(_filteredProducts);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Select Product',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Brand containers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: List.generate(_brands.length, (i) {
                final brand = _brands[i];
                final isSelected = _selectedBrand == brand;
                final brandColor = AppColors.getBrandPrimary(brand);
                final count = widget.products
                    .where((p) => p.brand == brand)
                    .length;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectBrand(brand),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: i < _brands.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? brandColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? brandColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: brandColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.format_paint_rounded,
                            size: 22,
                            color: isSelected ? Colors.white : brandColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brand.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$count items',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search in $_selectedBrand...',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _filter,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Product list grouped by category
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.trim().isEmpty
                                ? 'No products in $_selectedBrand'
                                : 'No products found for "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            color: Colors.grey.shade50,
                            child: Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getBrandPrimary(
                                  _selectedBrand,
                                ),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // Products in this category
                          ...entry.value.map(
                            (p) => ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      p.imageUrl != null &&
                                          p.imageUrl!.isNotEmpty
                                      ? Colors.transparent
                                      : _hexToColor(p.colorHex),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image:
                                      (p.imageUrl != null &&
                                          p.imageUrl!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(p.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                              title: Text(
                                _productLabel(p),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${p.subCategory}${p.unit != 'L' ? ' • ${p.unit}' : ''}${p.minQuantity > 1 ? ' • Min: ${p.minQuantity}' : ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              dense: true,
                              onTap: () => Navigator.pop(context, p),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemEntry {
  ProductModel? selectedProduct;
  String? selectedSize;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController shadeCodeCtrl = TextEditingController();

  double get finalLineTotal {
    if (selectedProduct == null || selectedSize == null) return 0.0;
    // Real implementation would pass actual needed prices.
    // For calculating the bottom sheet total, we need a way to access DataService.
    return 0.0;
  }

  void dispose() {
    qtyCtrl.dispose();
    shadeCodeCtrl.dispose();
  }
}
