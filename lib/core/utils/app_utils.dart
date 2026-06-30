import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppUtils {
  static void copyAddressToClipboard(BuildContext context, String address) async {
    if (address.isEmpty || address.toLowerCase().contains('no site location')) return;
    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (!context.mounted) return;
      _showCustomToast(context, 'address copied', true);
    } catch (e) {
      if (!context.mounted) return;
      _showCustomToast(context, 'address copying unsuccessful try again', false);
    }
  }

  static void _showCustomToast(BuildContext context, String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
