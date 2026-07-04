import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/banner_model.dart';
import '../../../core/constants/app_colors.dart';

/// Shows a full-screen popup overlay with the promotional banners
/// auto-swiping every 5 seconds. Called once per session when the
/// painter first lands on the home screen.
Future<void> showBannerPopup(
  BuildContext context,
  List<BannerModel> banners,
) async {
  if (banners.isEmpty) return;
  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    barrierDismissible: true,
    builder: (ctx) => _BannerPopupDialog(banners: banners),
  );
}

class _BannerPopupDialog extends StatefulWidget {
  final List<BannerModel> banners;
  const _BannerPopupDialog({required this.banners});

  @override
  State<_BannerPopupDialog> createState() => _BannerPopupDialogState();
}

class _BannerPopupDialogState extends State<_BannerPopupDialog> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _ctrl.animateToPage(next,
            duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _openFullscreen(BannerModel banner) {
    Navigator.pop(context); // close popup first
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.transparent, width: double.infinity, height: double.infinity),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        height: 300,
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.broken_image_rounded,
                            size: 48, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner pages
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: widget.banners.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) {
                      final banner = widget.banners[i];
                      return GestureDetector(
                        onTap: () => _openFullscreen(banner),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              banner.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                              ),
                            ),
                            if (banner.title != null && banner.title!.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black54, Colors.transparent],
                                    ),
                                  ),
                                  child: Text(
                                    banner.title!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            // Zoom hint
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.zoom_in_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Tap to zoom',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Dot indicators + close button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Row(
                    children: [
                      if (widget.banners.length > 1)
                        Expanded(
                          child: Row(
                            children: List.generate(
                              widget.banners.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _current == i ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _current == i
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // X close button at top-right corner
          Positioned(
            top: -14,
            right: -14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
