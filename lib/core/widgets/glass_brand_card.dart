import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// A claymorphic brand card with soft shadows and tap animation.
class GlassBrandCard extends StatefulWidget {
  final String brandName;
  final String subtitle;
  final IconData? icon;
  final String? imageUrl;
  final Color gradientStart;
  final Color gradientEnd;
  final Color glassTint;
  final String productCount;
  final VoidCallback onTap;

  const GlassBrandCard({
    super.key,
    required this.brandName,
    required this.subtitle,
    this.icon,
    this.imageUrl,
    required this.gradientStart,
    required this.gradientEnd,
    required this.glassTint,
    required this.productCount,
    required this.onTap,
  });

  @override
  State<GlassBrandCard> createState() => _GlassBrandCardState();
}

class _GlassBrandCardState extends State<GlassBrandCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD1CCC4).withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(4, 4),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 12,
                offset: Offset(-4, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Brand icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.gradientStart,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: widget.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            widget.icon ?? Icons.format_paint_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      )
                    : Icon(widget.icon ?? Icons.format_paint_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.brandName,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSlate,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSlateLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.gradientStart.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.productCount,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.gradientStart,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSlateLight,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
