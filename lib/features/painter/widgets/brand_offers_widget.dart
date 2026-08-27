import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/promotion_model.dart';

class BrandOffersWidget extends StatefulWidget {
  final List<PromotionModel> offers;
  final String brand;

  const BrandOffersWidget({super.key, required this.offers, required this.brand});

  @override
  State<BrandOffersWidget> createState() => _BrandOffersWidgetState();
}

class _BrandOffersWidgetState extends State<BrandOffersWidget> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    // Celebration animation
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.elasticOut,
    ));
    
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return 'Expired';
    return '${d.inDays.toString().padLeft(2, '0')}days ${(d.inHours % 24).toString().padLeft(2, '0')}hours ${(d.inMinutes % 60).toString().padLeft(2, '0')}min ${(d.inSeconds % 60).toString().padLeft(2, '0')}sec';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 140, // Height for the offers carousel
        child: PageView.builder(
          itemCount: widget.offers.length,
          itemBuilder: (context, index) {
            final offer = widget.offers[index];
            final timeLeft = offer.endDate.difference(DateTime.now());
            final brandColor = AppColors.getBrandPrimary(widget.brand);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandColor.withValues(alpha: 0.85), brandColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Icon
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.redeem_rounded,
                      size: 100,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              offer.title.isNotEmpty ? '${offer.title[0].toUpperCase()}${offer.title.substring(1)}' : offer.title,
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(offer.discountPercent * 100).toStringAsFixed(0)}% OFF',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Colors.white.withValues(alpha: 0.9), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(timeLeft),
                            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
