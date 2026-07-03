import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

/// Non-dismissible rejection gate — shown once after admin rejects bank details.
/// Disappears permanently after the painter taps "Try Again".
class PainterBankRejectedScreen extends ConsumerStatefulWidget {
  const PainterBankRejectedScreen({super.key});

  @override
  ConsumerState<PainterBankRejectedScreen> createState() =>
      _PainterBankRejectedScreenState();
}

class _PainterBankRejectedScreenState
    extends ConsumerState<PainterBankRejectedScreen> {
  bool _marking = false;

  Future<void> _tryAgain() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _marking = true);
    try {
      await ref.read(dataServiceProvider).markBankRejectionSeen(user.id);
      if (mounted) context.go('/painter/bank-details');
    } catch (_) {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Non-dismissible
      child: Scaffold(
        backgroundColor: const Color(0xFFF0EDE8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Red icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Bank Details\nNot Approved',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Your bank details were reviewed and could not be approved. '
                  'Please re-upload a clear photo of your bank passbook and '
                  'enter your account number again, then resubmit.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _marking ? null : _tryAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: _marking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Try Again',
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w700),
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
