import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../models/promotion_model.dart';

/// Interactive active offers carousel displayed on the painter home page.
/// Displays active promotions with countdown timer and navigates directly
/// to that brand's product catalog screen when tapped.
class HomeActiveOffersWidget extends StatefulWidget {
  final List<PromotionModel> offers;
  final void Function(String brand) onBrandTap;

  const HomeActiveOffersWidget({
    super.key,
    required this.offers,
    required this.onBrandTap,
  });

  @override
  State<HomeActiveOffersWidget> createState() => _HomeActiveOffersWidgetState();
}

class _HomeActiveOffersWidgetState extends State<HomeActiveOffersWidget> {
  late final PageController _pageController;
  Timer? _countdownTimer;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 1-second periodic tick to keep countdown clock fresh
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Auto-advance if more than 1 offer is active
    if (widget.offers.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentPage + 1) % widget.offers.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return 'Expired';
    if (d.inDays > 0) {
      return '${d.inDays}d ${(d.inHours % 24)}h left';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${(d.inMinutes % 60)}m left';
    }
    return '${d.inMinutes}m ${(d.inSeconds % 60)}s left';
  }

  String _getDiscountText(PromotionModel offer) {
    if (offer.discountPercent > 0) {
      return '${(offer.discountPercent * 100).toStringAsFixed(0)}% OFF';
    } else if (offer.discountFlat > 0) {
      return '₹${offer.discountFlat.toStringAsFixed(0)} OFF';
    }
    return 'OFFER';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.offers.length,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
            },
            itemBuilder: (context, index) {
              final offer = widget.offers[index];
              final gradient = AppColors.getBrandGradient(offer.brand);
              final primaryColor = AppColors.getBrandPrimary(offer.brand);
              final timeLeft = offer.endDate.difference(DateTime.now());

              return GestureDetector(
                onTap: () {
                  HapticService.light();
                  widget.onBrandTap(offer.brand);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient[0],
                        gradient[1],
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        // Decorative watermarked background icon
                        Positioned(
                          right: -15,
                          bottom: -20,
                          child: Icon(
                            Icons.local_offer_rounded,
                            size: 130,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        // Glass circle shimmer decoration
                        Positioned(
                          top: -30,
                          left: -30,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top row: Brand pill & "Shop Brand →"
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          offer.brand.toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Shop Now',
                                          style: GoogleFonts.poppins(
                                            color: primaryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: primaryColor,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Middle: Title & discount
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          offer.title.isNotEmpty
                                              ? '${offer.title[0].toUpperCase()}${offer.title.substring(1)}'
                                              : 'Special Offer',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tap to browse products',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getDiscountText(offer),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // Bottom: Countdown timer
                              Row(
                                children: [
                                  Icon(
                                    Icons.alarm_rounded,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatDuration(timeLeft),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.offers.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.offers.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
