import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_support.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/cart_service.dart';
import '../shared/widgets/product_image.dart';
import '../../core/utils/responsive.dart';

/// Painter screen to view bills sent by admin.
/// User can view the bill image and proceed to select a payment method.
class PainterBillsScreen extends ConsumerStatefulWidget {
  const PainterBillsScreen({super.key});

  @override
  ConsumerState<PainterBillsScreen> createState() =>
      _PainterBillsScreenState();
}

class _PainterBillsScreenState extends ConsumerState<PainterBillsScreen> {
  static const int _pageSize = 8;
  int _visibleCount = _pageSize;

  Future<void> _onRefresh(DataService ds) async {
    await ds.refresh();
    if (mounted) setState(() => _visibleCount = _pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final ds = ref.watch(dataServiceProvider);

    if (user == null) return const SizedBox.shrink();

    final billedOrders = ds.getBilledOrdersForPainter(user.id);
    final visibleOrders = billedOrders.take(_visibleCount).toList();
    final hasMore = billedOrders.length > visibleOrders.length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/painter'),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text('My Bills',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: RefreshIndicator(
            onRefresh: () => _onRefresh(ds),
            child: billedOrders.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height - 180,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No bills yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              )),
                          const SizedBox(height: 8),
                          Text(
                            'Bills will appear here once the admin\ngenerates them for your orders.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleOrders.length + (hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= visibleOrders.length) {
                        // "Load More" footer row
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                  () => _visibleCount += _pageSize),
                              icon: const Icon(Icons.expand_more_rounded, size: 18),
                              label: Text(
                                'Load More (${billedOrders.length - visibleOrders.length} left)',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        );
                      }
                      final order = visibleOrders[i];
                      return _buildBillCard(order, ds);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(dynamic order, DataService ds) {
    final brandColor = AppColors.getBrandPrimary(order.brand);
    final hasBillUrl = order.billImageUrl != null && order.billImageUrl!.isNotEmpty;
    final isPendingReveal = !hasBillUrl && (order.status == 'udhaari_pending_approval' || order.status == 'to_be_revealed' || order.status == 'udhaari_no_bill');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  child: () {
                    final brandLower = order.brand.toLowerCase();
                    String? imageUrl;
                    if (brandLower.contains('birla')) {
                      imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus.png';
                    } else if (brandLower.contains('asian')) {
                      imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/ap.png';
                    } else if (brandLower.contains('berger')) {
                      imageUrl = 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/berger.png';
                    }
                    return imageUrl != null
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.network(imageUrl, fit: BoxFit.contain),
                          )
                        : Icon(Icons.receipt_rounded, color: brandColor, size: 24);
                  }(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.brand,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${order.items.length} items • ${DateFormat('dd MMM yyyy').format(order.createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPendingReveal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFFF9800)),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (order.hideAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '--',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: brandColor,
                      ),
                    ),
                  )
                else if (order.totalAmount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: brandColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // "Will be revealed" banner for pending_reveal
          if (isPendingReveal)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9800).withValues(alpha: 0.08),
                    const Color(0xFFFFC107).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 20, color: Color(0xFFFF9800)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount will be revealed by admin',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                        Text(
                          'The bill and final amount are being processed',
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
                children: [
                  ...order.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            ProductImage(
                              imageUrl: item.productImageUrl,
                              productId: item.productId,
                              brand: order.brand,
                              size: 24,
                              borderRadius: 6,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.productName} (${item.bucketSize}) x${item.quantity}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.shadeCode != null)
                                    Text(
                                      'Shade Code: ${item.shadeCode}',
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
                      )),
                  if (order.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 16),
                      child: Text(
                        '+ ${order.items.length - 3} more items...',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: brandColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Site location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.siteLocation,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Always show View Bill button if there's a bill URL
          if (hasBillUrl)
            GestureDetector(
              onTap: () => _showFullBill(order.billImageUrl!),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 32, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Bill',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          'Tap to open PDF',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Status & View Order
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isPendingReveal
                          ? const Color(0xFFFF9800).withValues(alpha: 0.08)
                          : AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPendingReveal ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                          size: 16,
                          color: isPendingReveal ? const Color(0xFFFF9800) : AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPendingReveal ? 'PENDING REVEAL' : order.displayStatus.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPendingReveal ? const Color(0xFFFF9800) : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Re-order to cart button
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => _reorderToCart(order),
                    icon: const Icon(Icons.add_shopping_cart_rounded,
                        size: 18, color: Color(0xFFFF9500)),
                    tooltip: 'Add to Cart',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextButton.icon(
                    onPressed: () => context.push('/painter/order-detail/${order.id}'),
                    icon: Icon(Icons.visibility_rounded, size: 16, color: brandColor),
                    label: Text('View Order',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brandColor,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reorderToCart(dynamic order) {
    final ds = ref.read(dataServiceProvider);
    int added = 0;
    for (final item in order.items) {
      final product = ds.getProductById(item.productId);
      if (product == null) continue;
      ref.read(cartProvider.notifier).addItem(
        product,
        item.bucketSize,
        shadeCode: item.shadeCode,
        quantity: item.quantity,
      );
      added++;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(added > 0
              ? '$added item${added == 1 ? '' : 's'} added to cart!'
              : 'No products found to add'),
          backgroundColor:
              added > 0 ? const Color(0xFFFF9500) : AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  void _showFullBill(String url) async {
    final isPdf = url.toLowerCase().endsWith('.pdf');

    // On Windows/desktop, PdfPreview is not supported — open in system browser.
    if (PlatformSupport.isDesktop) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open bill. Try copying the URL manually.')),
        );
      }
      return;
    }

    // Mobile: download and display.
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        if (isPdf || response.headers['content-type']?.contains('pdf') == true) {
          _showPdfViewer(response.bodyBytes);
        } else {
          _showImageDialog(url);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bill (${response.statusCode})')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bill: $e')),
        );
      }
    }
  }

  void _showPdfViewer(List<int> pdfBytes) {
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
            build: (format) async => Uint8List.fromList(pdfBytes),
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

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 300,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

