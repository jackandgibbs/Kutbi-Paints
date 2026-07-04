import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../providers/auth_provider.dart';

class PainterScannerScreen extends ConsumerStatefulWidget {
  const PainterScannerScreen({super.key});

  @override
  ConsumerState<PainterScannerScreen> createState() => _PainterScannerScreenState();
}

class _PainterScannerScreenState extends ConsumerState<PainterScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  MobileScannerController controller = MobileScannerController();
  final TextEditingController _manualIdCtrl = TextEditingController();
  final FocusNode _manualIdFocus = FocusNode();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _manualIdCtrl.dispose();
    _manualIdFocus.dispose();
    _pulseController.dispose();
    controller.dispose();
    super.dispose();
  }

  String? _extractQRId(String code) {
    final trimmedCode = code.trim();
    final upperCode = trimmedCode.toUpperCase();

    if (upperCode.startsWith('QR')) return upperCode;
    if (trimmedCode.contains('/redeem/')) {
      try {
        final uri = Uri.parse(trimmedCode);
        if (uri.pathSegments.isNotEmpty) return uri.pathSegments.last.toUpperCase();
      } catch (_) {}
    }
    if (trimmedCode.contains('qr_id=')) {
      try {
        final cleanUrl = trimmedCode.startsWith('kutbi://')
            ? trimmedCode.replaceFirst('kutbi://', 'https://')
            : trimmedCode;
        final uri = Uri.parse(cleanUrl);
        return uri.queryParameters['qr_id']?.toUpperCase();
      } catch (_) {}
    }
    return null;
  }

  Future<void> _processCode(String rawCode, {bool isManual = false}) async {
    if (_isProcessing) return;

    String? qrId = _extractQRId(rawCode);
    if (qrId == null) {
      final cleaned = rawCode.trim().toUpperCase();
      if (cleaned.isNotEmpty) qrId = cleaned;
    }

    if (qrId == null || qrId.isEmpty) {
      _showError('Invalid code. Please scan a Kutbi Paints sticker or enter a valid ID.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      // Pass the raw scanned value only if it was camera-scanned (not manual)
      final scannedValue = isManual ? qrId : rawCode;
      final result = await ref.read(dataServiceProvider).redeemQRCode(qrId, user.id, scannedValue: scannedValue);

      if (result.startsWith('success')) {
        await ref.read(dataServiceProvider).refresh();
        int pointsEarned = 0;
        if (result.contains(':')) {
          pointsEarned = int.tryParse(result.split(':').last) ?? 0;
        }
        _showCongratulations(pointsEarned);
      } else if (result.startsWith('point_error')) {
        await ref.read(dataServiceProvider).refresh();
        _showCongratulations(0, warning: true);
      } else if (result == 'used') {
        _showAlreadyScanned();
      } else if (result == 'expired') {
        _showError('This sticker has expired.');
      } else if (result == 'invalid') {
        _showError('Code not found. Please check the ID and try again.');
      } else {
        _showError('System error. Please try again later.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final String? code = barcodes.first.rawValue;
    if (code == null) return;
    _processCode(code);
  }

  void _submitManualId() {
    final text = _manualIdCtrl.text.trim();
    if (text.isEmpty) {
      _showError('Please enter a Unique ID.');
      return;
    }
    _manualIdFocus.unfocus();
    _processCode(text, isManual: true);
    _manualIdCtrl.clear();
  }

  void _showCongratulations(int points, {bool warning = false}) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _CelebrationDialog(points: points, warning: warning),
    );
  }

  void _showAlreadyScanned() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => const _AlreadyScannedDialog(),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Scan QR Sticker',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: Colors.yellow);
                  default:
                    return const Icon(Icons.flash_off_rounded, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Scanner Area ───
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                ),
                // Scanner frame overlay
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.02);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary.withValues(
                                  alpha: 0.6 + _pulseController.value * 0.4),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Scan hint
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Center the sticker QR in the box',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Manual ID Input ───
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Or enter Unique ID manually',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        child: TextField(
                          controller: _manualIdCtrl,
                          focusNode: _manualIdFocus,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1a1a2e),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                          cursorColor: AppColors.primary,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'e.g. QR-A1B2C3D4',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(Icons.qr_code_rounded,
                                color: AppColors.primary, size: 22),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (_) => _submitManualId(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isProcessing ? null : _submitManualId,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Already Scanned Dialog ─────────────────────────────────────────────
class _AlreadyScannedDialog extends StatefulWidget {
  const _AlreadyScannedDialog();

  @override
  State<_AlreadyScannedDialog> createState() => _AlreadyScannedDialogState();
}

class _AlreadyScannedDialogState extends State<_AlreadyScannedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFA8E6CF), // App scaffold mint green
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Already Scanned!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This QR code has already been\nredeemed by someone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Each sticker can only be used once.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Got it',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Celebration Dialog with Built-in Confetti ──────────────────────────
class _CelebrationDialog extends StatefulWidget {
  final int points;
  final bool warning;
  const _CelebrationDialog({required this.points, this.warning = false});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _confettiCtrl;
  late final Animation<double> _scaleAnim;
  final List<_ConfettiParticle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Generate confetti particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        vx: (_random.nextDouble() - 0.5) * 2,
        vy: _random.nextDouble() * 3 + 1,
        size: _random.nextDouble() * 8 + 4,
        color: [
          const Color(0xFFFFD700),
          const Color(0xFF6366F1),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
          const Color(0xFF8B5CF6),
          const Color(0xFF06B6D4),
        ][_random.nextInt(7)],
        rotation: _random.nextDouble() * 6.28,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      ));
    }

    _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti overlay
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (context, child) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ConfettiPainter(
                progress: _confettiCtrl.value,
                particles: _particles,
              ),
            );
          },
        ),
        // Dialog
        Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFA8E6CF), // App scaffold background (mint green)
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trophy icon with glow
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '🎉 Congratulations! 🎉',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You just earned',
                      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    // Points badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            widget.points > 0 ? '+${widget.points} Points' : 'Points',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Added to your wallet instantly!',
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF374151)),
                    ),
                    if (widget.warning) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '⚠ Point sync might be delayed. Check your wallet later.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Awesome! 🚀',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Confetti Rendering ─────────────────────────────────────────────────

class _ConfettiParticle {
  double x, y, vx, vy, size, rotation, rotationSpeed;
  Color color;
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final x = (p.x + p.vx * t * 0.15) * size.width;
      final y = (p.y + p.vy * t) * size.height;
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      if (y > size.height || y < 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
