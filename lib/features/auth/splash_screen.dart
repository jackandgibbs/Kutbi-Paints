import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/splash_shown_provider.dart';
import '../../services/data_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _dripController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  bool _hasNavigated = false;
  bool _isAnimationDone = false;

  @override
  void initState() {
    super.initState();

    // Paint drip animation
    _dripController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..forward();

    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _textSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // Sequence: drips → logo → text → navigate
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _isAnimationDone = true);
        _navigate();
      }
    });
  }

  Future<void> _navigate() async {
    if (_hasNavigated || !mounted) return;

    // 1. Must be online to navigate
    final connectivity = ref.read(connectivityProvider);
    if (connectivity != ConnectivityStatus.isConnected) {
      debugPrint('SplashScreen: Still offline, waiting...');
      return;
    }

    // 2. Auth must not be loading
    if (ref.read(authProvider).isLoading) {
      debugPrint('SplashScreen: Auth still loading, waiting...');
      return;
    }

    // 3. If online but data isn't loaded (e.g. started offline and just connected), refresh it
    final dataService = ref.read(dataServiceProvider);
    if (!dataService.isLoaded) {
      debugPrint('SplashScreen: Data not loaded, auto-refreshing...');
      try {
        await dataService.refresh();
        await ref.read(authProvider.notifier).checkSavedLogin();
        // Return here because checkSavedLogin sets isLoading to true/false, 
        // which will re-trigger this method via the ref.listen(authProvider)
        return;
      } catch (e) {
        debugPrint('SplashScreen: Auto-refresh failed: $e');
        return;
      }
    }

    // 4. Animation must be done
    if (!_isAnimationDone) return;

    _hasNavigated = true;
    ref.read(splashShownProvider.notifier).state = true;
    final authState = ref.read(authProvider);
    if (authState.isLoggedIn) {
      if (authState.isAdmin) {
        context.go('/admin');
      } else {
        context.go('/painter');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _dripController.dispose();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Automatically navigate when state changes to connected/loaded
    ref.listen(connectivityProvider, (_, next) {
      if (next == ConnectivityStatus.isConnected) {
        _navigate();
      }
    });

    ref.listen(authProvider, (_, next) {
      if (!next.isLoading) {
        _navigate();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            width: size.width,
            height: size.height,
            color: AppColors.scaffoldBg,
          ),

          // Paint texture pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _PaintTexturePainter(),
            ),
          ),

          // Animated paint drips from top
          AnimatedBuilder(
            animation: _dripController,
            builder: (context, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _PaintDripPainter(
                    progress: _dripController.value,
                  ),
                ),
              );
            },
          ),

          // Center content — logo + text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Animated text
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            Text(
                              'KUTBI',
                              style: GoogleFonts.poppins(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 8,
                                height: 1,
                              ),
                            ),
                            Text(
                              'HARDWARE & PAINTS',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textSecondary,
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 50,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6D00),
                                    Color(0xFFFFAB40),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your Trusted Paint Partner',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textLight,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Brand strip at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _brandChip('Asian Paints', const Color(0xFF1565C0)),
                      const SizedBox(width: 12),
                      _brandChip('Berger', const Color(0xFFFBC02D)),
                      const SizedBox(width: 12),
                      _brandChip('Birla Opus', const Color(0xFF00897B)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        name,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.black.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

// ─── Paint Drip Painter ─────────────────────────────────────────
class _PaintDripPainter extends CustomPainter {
  final double progress;

  _PaintDripPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Generate multiple drips
    final drips = <_Drip>[
      _Drip(x: size.width * 0.1, maxHeight: size.height * 0.35, width: 18, delay: 0.0),
      _Drip(x: size.width * 0.25, maxHeight: size.height * 0.55, width: 14, delay: 0.1),
      _Drip(x: size.width * 0.4, maxHeight: size.height * 0.3, width: 20, delay: 0.15),
      _Drip(x: size.width * 0.55, maxHeight: size.height * 0.45, width: 12, delay: 0.05),
      _Drip(x: size.width * 0.7, maxHeight: size.height * 0.6, width: 16, delay: 0.2),
      _Drip(x: size.width * 0.85, maxHeight: size.height * 0.38, width: 22, delay: 0.08),
      _Drip(x: size.width * 0.95, maxHeight: size.height * 0.25, width: 10, delay: 0.25),
    ];

    final colors = [
      const Color(0xFFE53935), // Red
      const Color(0xFFFB8C00), // Orange
      const Color(0xFFFFD600), // Yellow
      const Color(0xFF43A047), // Green
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF8E24AA), // Purple
    ];

    for (int i = 0; i < drips.length; i++) {
      final drip = drips[i];
      final dripProgress = ((progress - drip.delay) / (1 - drip.delay)).clamp(0.0, 1.0);
      if (dripProgress <= 0) continue;

      final dripColor = colors[i % colors.length];
      final currentHeight = drip.maxHeight * Curves.easeInCubic.transform(dripProgress);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dripColor.withValues(alpha: 0.0),
            dripColor.withValues(alpha: 0.6),
            dripColor.withValues(alpha: 1.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(drip.x - drip.width / 2, 0, drip.width, currentHeight));

      // Draw drip body
      final path = Path();
      path.moveTo(drip.x - drip.width / 2, 0);
      path.lineTo(drip.x + drip.width / 2, 0);
      path.lineTo(drip.x + drip.width * 0.3, currentHeight - 10);
      // Drip bulb
      path.quadraticBezierTo(
        drip.x + drip.width * 0.4,
        currentHeight + 8,
        drip.x,
        currentHeight + 12,
      );
      path.quadraticBezierTo(
        drip.x - drip.width * 0.4,
        currentHeight + 8,
        drip.x - drip.width * 0.3,
        currentHeight - 10,
      );
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PaintDripPainter old) => old.progress != progress;
}

class _Drip {
  final double x;
  final double maxHeight;
  final double width;
  final double delay;

  _Drip({required this.x, required this.maxHeight, required this.width, required this.delay});
}

// ─── Paint Texture Painter ──────────────────────────────────────
class _PaintTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(123);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // Subtle dots to simulate paint texture
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PaintTexturePainter old) => false;
}
