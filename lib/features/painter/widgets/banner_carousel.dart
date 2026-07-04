import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/banner_model.dart';
import '../../../core/constants/app_colors.dart';

/// Auto-swiping banner carousel shown on the painter home page.
/// Each banner auto-advances after 5 seconds. Tapping a banner
/// opens a fullscreen zoomed overlay.
class BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _ctrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
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
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
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
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
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
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text(
            'Promotions',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final banner = widget.banners[i];
              return GestureDetector(
                onTap: () => _openFullscreen(banner),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.grey.shade200,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_outlined,
                              size: 48, color: Colors.grey),
                        ),
                      ),
                      // Gradient overlay for readability
                      if (banner.title != null && banner.title!.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      // Tap hint icon
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 20 : 6,
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
          ),
      ],
    );
  }
}
