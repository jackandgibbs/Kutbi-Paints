import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/product_image.dart';

class GlassOrderStack extends StatefulWidget {
  final List<dynamic> orders;
  final Function(String orderId, String nextStatus) onStatusUpdate;
  final Function(String orderId) onTapDetails;
  final String? Function(String status) getNextStatus;
  final String Function(String status) getActionLabel;
  final IconData Function(String status) getActionIcon;
  final String Function(String painterId) getPainterName;
  final String Function(String painterId) getPainterPhone;

  const GlassOrderStack({
    super.key,
    required this.orders,
    required this.onStatusUpdate,
    required this.onTapDetails,
    required this.getNextStatus,
    required this.getActionLabel,
    required this.getActionIcon,
    required this.getPainterName,
    required this.getPainterPhone,
  });

  @override
  State<GlassOrderStack> createState() => _GlassOrderStackState();
}

class _GlassOrderStackState extends State<GlassOrderStack> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return const Center(child: Text("No orders in this queue"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.orders.length,
              itemBuilder: (context, index) {
                final order = widget.orders[index];
                
                // Calculate 3D Perspective
                final double relativePosition = index - _currentPage;
                final double absPosition = relativePosition.abs();
                
                // Transformation values
                final double scale = (1 - (absPosition * 0.15)).clamp(0.0, 1.0);
                final double opacity = (1 - (absPosition * 0.5)).clamp(0.0, 1.0);
                final double rotationY = relativePosition * 0.3; // 3D Tilt
                final double translationX = relativePosition * 40; // Shift to side

                return Opacity(
                  opacity: opacity,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..scale(scale)
                      ..rotateY(rotationY)
                      ..translate(translationX),
                    alignment: Alignment.center,
                    child: _buildGlassCard(order),
                  ),
                );
              },
            ),
            // Floating Action Hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swipe_rounded, size: 16, color: AppColors.textLight),
                      const SizedBox(width: 8),
                      Text(
                        "Swipe deck to browse",
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassCard(dynamic order) {
    final brandColor = AppColors.getBrandPrimary(order.brand);
    final nextStatus = widget.getNextStatus(order.status);

    return Center(
      child: Container(
        height: 500,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: GlassContainer(
          borderRadius: 30,
          blur: 20,
          opacity: 0.1,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  ProductImage(
                    imageUrl: order.items.first.productImageUrl,
                    productId: order.items.first.productId,
                    brand: order.brand,
                    size: 60,
                    borderRadius: 15,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.brand,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: brandColor,
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(order.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onTapDetails(order.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              // Big Name
              Text(
                "Painter Name",
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                widget.getPainterName(order.painterId),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                widget.getPainterPhone(order.painterId),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // Items Summary
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length > 3 ? 3 : order.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = order.items[i];
                    return Row(
                      children: [
                        Container(
                          width: 4,
                          height: 30,
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${item.bucketSize} x ${item.quantity}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              if (order.items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "+ ${order.items.length - 3} more items",
                    style: GoogleFonts.poppins(fontSize: 11, color: brandColor, fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 30),
              
              // Action Button
              if (nextStatus != null)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => widget.onStatusUpdate(order.id, nextStatus),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.getActionIcon(nextStatus)),
                        const SizedBox(width: 12),
                        Text(
                          widget.getActionLabel(nextStatus),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
