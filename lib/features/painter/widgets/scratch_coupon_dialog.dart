import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A premium scratch coupon dialog that reveals the reward amount
class ScratchCouponDialog extends StatefulWidget {
  final double rewardAmount;
  final String goalTitle;
  final String brand;
  final VoidCallback onClaimed;

  const ScratchCouponDialog({
    super.key,
    required this.rewardAmount,
    required this.goalTitle,
    required this.brand,
    required this.onClaimed,
  });

  @override
  State<ScratchCouponDialog> createState() => _ScratchCouponDialogState();
}

class _ScratchCouponDialogState extends State<ScratchCouponDialog>
    with TickerProviderStateMixin {
  // Scratch state
  final Set<Offset> _scratchPoints = {};
  bool _isRevealed = false;
  double _scratchProgress = 0;

  // Animations
  late AnimationController _confettiCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_isRevealed) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      _scratchPoints.add(localPosition);
      // Calculate scratch progress based on unique grid cells covered
      final gridSize = 20.0;
      final totalCells = (size.width / gridSize) * (size.height / gridSize);
      final coveredCells = <String>{};
      for (final p in _scratchPoints) {
        final gx = (p.dx / gridSize).floor();
        final gy = (p.dy / gridSize).floor();
        coveredCells.add('$gx,$gy');
      }
      _scratchProgress = (coveredCells.length / totalCells).clamp(0.0, 1.0);

      if (_scratchProgress > 0.35 && !_isRevealed) {
        _isRevealed = true;
        _confettiCtrl.forward();
        _pulseCtrl.stop();
        widget.onClaimed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = AppColors.getBrandPrimary(widget.brand);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: brandColor.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandColor, brandColor.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'Congratulations!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.goalTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Scratch Area
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (!_isRevealed)
                    Text(
                      'Scratch to reveal your reward!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Scratch card area
                  ScaleTransition(
                    scale: _isRevealed
                        ? const AlwaysStoppedAnimation(1.0)
                        : _pulseAnim,
                    child: GestureDetector(
                      onPanUpdate: (details) =>
                          _onPanUpdate(details, const Size(260, 140)),
                      child: Container(
                        width: 260,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isRevealed
                                ? AppColors.success
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              // Reward underneath
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.success.withValues(alpha: 0.1),
                                      AppColors.success.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${widget.rewardAmount.toStringAsFixed(0)} Coins',
                                      style: GoogleFonts.poppins(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    Text(
                                      'REWARD WON! 🎊',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Scratch overlay
                              if (!_isRevealed)
                                CustomPaint(
                                  size: const Size(260, 140),
                                  painter: _ScratchPainter(
                                    scratchPoints: _scratchPoints,
                                    brandColor: brandColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Confetti or instruction
                  if (_isRevealed) ...[
                    AnimatedBuilder(
                      animation: _confettiCtrl,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(260, 60),
                          painter: _ConfettiPainter(
                            progress: _confettiCtrl.value,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reward has been added to your account!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRevealed ? AppColors.success : brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isRevealed ? 'Awesome!' : 'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the scratch-off overlay
class _ScratchPainter extends CustomPainter {
  final Set<Offset> scratchPoints;
  final Color brandColor;

  _ScratchPainter({required this.scratchPoints, required this.brandColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the base scratch layer
    final bgPaint = Paint()..color = brandColor.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)),
      bgPaint,
    );

    // Draw scratch pattern (coins/stars)
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (double x = 20; x < size.width; x += 50) {
      for (double y = 20; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 8, patternPaint);
      }
    }

    // Draw "SCRATCH HERE" text
    final textSpan = TextSpan(
      text: '✨ SCRATCH HERE ✨',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    // Erase scratched areas
    final erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 40
      ..style = PaintingStyle.stroke;

    if (scratchPoints.length > 1) {
      final path = Path();
      final points = scratchPoints.toList();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, erasePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchPainter oldDelegate) => true;
}

/// Simple confetti animation painter
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42);

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
      const Color(0xFFFF6B9D),
      const Color(0xFFC77DFF),
    ];

    for (int i = 0; i < 30; i++) {
      final x = _random.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height + 20;
      final y = startY + (endY - startY) * progress;
      final wobble = sin(progress * 3.14 * 2 + i) * 10;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 1.0 - progress * 0.5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + wobble, y + _random.nextDouble() * 20),
            width: 6,
            height: 10,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
