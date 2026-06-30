import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/splash_shown_provider.dart';
import 'claymorphic_loading_bar.dart';

/// A reusable Lottie-based loading widget.
/// Shows full animation only on first load, then uses minimal progress bar.
class LottieLoadingWidget extends ConsumerWidget {
  final String? message;
  final double size;

  const LottieLoadingWidget({
    super.key,
    this.message,
    this.size = 120,
  });

  /// The Supabase-hosted Lottie URL (fallback / remote option)
  static const String supabaseUrl =
      'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/animations/loading.json';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashShown = ref.watch(splashShownProvider);
    
    // After splash, use minimal claymorphic loading bar
    if (splashShown) {
      return ClaymorphicLoadingBar(message: message);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animations/loading.json',
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to network version from Supabase
                return Lottie.network(
                  supabaseUrl,
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) {
                    // Ultimate fallback: a simple spinner
                    return const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF635BFF),
                    );
                  },
                );
              },
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: GoogleFonts.poppins(
                fontSize: 14,
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
