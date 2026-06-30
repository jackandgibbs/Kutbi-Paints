import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A minimal claymorphic loading bar for subsequent loads after splash.
class ClaymorphicLoadingBar extends StatefulWidget {
  final String? message;
  const ClaymorphicLoadingBar({super.key, this.message});

  @override
  State<ClaymorphicLoadingBar> createState() => _ClaymorphicLoadingBarState();
}

class _ClaymorphicLoadingBarState extends State<ClaymorphicLoadingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E4DF),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(-2, -2),
                ),
                BoxShadow(
                  color: const Color(0xFFD1CCC4).withValues(alpha: 0.5),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Stack(
                    children: [
                      Positioned(
                        left: (_controller.value * 260) - 60,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF635BFF).withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.message!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
