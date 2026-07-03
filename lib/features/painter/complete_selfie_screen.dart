import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

/// Forced onboarding gate: a painter must capture a live selfie (camera only,
/// no gallery) before they can access the rest of the app. Shown by the router
/// redirect when the signed-in painter has no `profileImageUrl` yet.
class CompleteSelfieScreen extends ConsumerStatefulWidget {
  const CompleteSelfieScreen({super.key});

  @override
  ConsumerState<CompleteSelfieScreen> createState() =>
      _CompleteSelfieScreenState();
}

class _CompleteSelfieScreenState extends ConsumerState<CompleteSelfieScreen> {
  File? _selfie;
  bool _isSaving = false;

  Future<void> _takeSelfie() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked != null) {
        setState(() => _selfie = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera: $e')),
        );
      }
    }
  }

  Future<void> _confirm() async {
    final user = ref.read(authProvider).user;
    if (_selfie == null || user == null) return;

    setState(() => _isSaving = true);
    try {
      final ds = ref.read(dataServiceProvider);
      final bytes = await _selfie!.readAsBytes();
      final fileName = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await ds.uploadProfileImage(user.id, bytes, fileName);
      await ds.updateUserProfileImage(user.id, url);
      // Refresh auth state so the router gate re-evaluates and lets us through.
      ref.read(authProvider.notifier).refreshUser();

      if (mounted) context.go('/painter');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save selfie: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Non-dismissible: block system back so the gate can't be skipped.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.account_circle_rounded,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Add your photo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please take a quick selfie to set up your profile. '
                  'This is required to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _isSaving ? null : _takeSelfie,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 2),
                          image: _selfie != null
                              ? DecorationImage(
                                  image: FileImage(_selfie!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _selfie == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      size: 48,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(height: 10),
                                  Text('Tap to take selfie',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      )),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_selfie != null)
                  TextButton.icon(
                    onPressed: _isSaving ? null : _takeSelfie,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Retake',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_selfie == null || _isSaving) ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Continue',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600)),
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
