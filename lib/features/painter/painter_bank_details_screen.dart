import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';

class PainterBankDetailsScreen extends ConsumerStatefulWidget {
  const PainterBankDetailsScreen({super.key});

  @override
  ConsumerState<PainterBankDetailsScreen> createState() =>
      _PainterBankDetailsScreenState();
}

class _PainterBankDetailsScreenState
    extends ConsumerState<PainterBankDetailsScreen> {
  final _accountCtrl = TextEditingController();
  XFile? _passbookImage;
  bool _submitting = false;

  @override
  void dispose() {
    _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPassbook() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _passbookImage = picked);
  }

  Future<void> _submit() async {
    final account = _accountCtrl.text.trim();
    if (account.isEmpty) {
      _snack('Please enter your bank account number');
      return;
    }
    if (_passbookImage == null) {
      _snack('Please upload your bank passbook image');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = ref.read(authProvider).user!;
      final ds = ref.read(dataServiceProvider);

      final bytes = await _passbookImage!.readAsBytes();
      final url = await ds.uploadBankPassbook(
        user.id,
        bytes,
        'passbook_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ds.updateUserBankDetails(user.id, account, url);

      // Notify admin device (local notification — fires on this device,
      // which for painters is their own device; the red dot in admin UI
      // serves as the real admin-side alert).
      await NotificationService.showAdminBankPending(painterName: user.name);

      if (mounted) {
        _snack('Request submitted! Waiting for admin approval.', success: true);
        setState(() {});
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    // Reflect live status from DataService (updates after admin action)
    final liveUser =
        ref.watch(dataServiceProvider).getUserById(user.id) ?? user;
    final status = liveUser.bankStatus;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Bank Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (status != 'none') _statusChip(status),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: status == 'approved'
                  ? _buildApprovedView(liveUser)
                  : status == 'pending'
                      ? _buildPendingView(liveUser)
                      : _buildForm(liveUser),
            ),
          ),
        ],
      ),
    );
  }

  // ── Approved ────────────────────────────────────────────────────
  Widget _buildApprovedView(dynamic user) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 56),
              const SizedBox(height: 12),
              Text(
                'Bank Details Approved',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your bank details are verified and active.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoCard(
          icon: Icons.account_balance_rounded,
          label: 'Account Number',
          value: user.bankAccountNumber ?? '—',
        ),
        if (user.bankPassbookUrl != null) ...[
          const SizedBox(height: 16),
          _passbookPreviewCard(user.bankPassbookUrl!),
        ],
      ],
    );
  }

  // ── Pending ─────────────────────────────────────────────────────
  Widget _buildPendingView(dynamic user) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Colors.white, size: 56),
              const SizedBox(height: 12),
              Text(
                'Request In Progress',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your bank details have been submitted.\nPlease wait for admin approval.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoCard(
          icon: Icons.account_balance_rounded,
          label: 'Account Number',
          value: user.bankAccountNumber ?? '—',
        ),
        if (user.bankPassbookUrl != null) ...[
          const SizedBox(height: 16),
          _passbookPreviewCard(user.bankPassbookUrl!),
        ],
      ],
    );
  }

  // ── Form (none / rejected) ───────────────────────────────────────
  Widget _buildForm(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Enter your bank details below to receive commissions directly into your account.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Account number
        Text(
          'Account Number',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _accountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'e.g. 1234567890',
            hintStyle: GoogleFonts.poppins(color: AppColors.textLight),
            prefixIcon: const Icon(Icons.account_balance_rounded,
                color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 24),

        // Passbook image
        Text(
          'Bank Passbook / Cheque Photo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickPassbook,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _passbookImage != null
                    ? AppColors.primary
                    : const Color(0xFFE0DDD9),
                width: 2,
              ),
            ),
            child: _passbookImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_rounded,
                          size: 40, color: AppColors.textLight),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload passbook image',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textLight),
                      ),
                      Text(
                        'Gallery only • JPG / PNG',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textLight),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FutureBuilder<Uint8List>(
                      future: _passbookImage!.readAsBytes(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(snap.data!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _pickPassbook,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'Submit Info',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passbookPreviewCard(String url) {
    return GestureDetector(
      onTap: () => _showFullImage(url),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(url, fit: BoxFit.cover),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    'Tap to view full image',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (color, label) = switch (status) {
      'approved' => (const Color(0xFF10B981), 'Approved'),
      'pending' => (const Color(0xFFF59E0B), 'Pending'),
      'rejected' => (AppColors.error, 'Rejected'),
      _ => (AppColors.textLight, 'None'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
