import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';

/// A modern skeuomorphic background with subtle paper texture,
/// a top-left light source, and a soft gradient depth illusion.
class SkeuomorphicBackground extends StatelessWidget {
  final Widget child;

  const SkeuomorphicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Layer 0: Solid theme background ───────────────────
        Positioned.fill(
          child: Container(
            color: AppColors.scaffoldBg,
          ),
        ),

        // ── Layer 1: Top-left light source (radial glow) ───────
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // ── Layer 2: Subtle texture pattern ────────────────────
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SubtleTexturePainter(),
            ),
          ),
        ),

        // ── Layer 3: Very subtle bottom vignette for depth ─────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.02),
                ],
                stops: const [0.7, 1.0],
              ),
            ),
          ),
        ),

        // ── Content ────────────────────────────────────────────
        child,
      ],
    );
  }
}

/// Paints a very subtle matte/paper texture using tiny dots.
/// Lightweight — uses deterministic positioning for consistency.
class _SubtleTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.012)
      ..style = PaintingStyle.fill;

    final rng = math.Random(42); // deterministic seed
    final count = (size.width * size.height / 600).clamp(200, 3000).toInt();

    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 0.6 + 0.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
