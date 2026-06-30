import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/data_service.dart';

class ProductImage extends ConsumerWidget {
  final String? imageUrl;
  final String productId;
  final String brand;
  final double size;
  final double borderRadius;
  final String? heroTag;

  const ProductImage({
    super.key,
    this.imageUrl,
    required this.productId,
    required this.brand,
    this.size = 44,
    this.borderRadius = 12,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    
    // Fallback logic for historical orders/activity
    String? effectiveUrl = imageUrl;
    if (effectiveUrl == null || effectiveUrl.isEmpty) {
      try {
        final product = ds.getAllProducts().firstWhere((p) => p.id == productId);
        effectiveUrl = product.imageUrl;
      } catch (_) {
        // Not found in catalog
      }
    }

    final brandColor = AppColors.getBrandPrimary(brand);

    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: (effectiveUrl != null && effectiveUrl.isNotEmpty)
            ? Image.network(
                effectiveUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(brandColor),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: child,
                    );
                  }
                  return _buildPlaceholder(brandColor);
                },
              )
            : _buildPlaceholder(brandColor),
      ),
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildPlaceholder(Color color) {
    final iconSize = (size * 0.5).clamp(12.0, 48.0);
    return Icon(
      Icons.format_paint_rounded,
      color: color,
      size: iconSize,
    );
  }
}
