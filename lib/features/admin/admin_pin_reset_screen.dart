import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';

class AdminPinResetScreen extends ConsumerStatefulWidget {
  const AdminPinResetScreen({super.key});

  @override
  ConsumerState<AdminPinResetScreen> createState() => _AdminPinResetScreenState();
}

class _AdminPinResetScreenState extends ConsumerState<AdminPinResetScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSearching = false;
  bool _isResetting = false;
  dynamic _foundUser;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
    });

    // Small delay for UI feel
    await Future.delayed(const Duration(milliseconds: 400));
    
    final user = ref.read(dataServiceProvider).findUserByPhone(phone);
    
    setState(() {
      _foundUser = user;
      _isSearching = false;
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No painter found with this phone number'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_foundUser == null) return;

    setState(() => _isResetting = true);

    try {
      await ref.read(dataServiceProvider).updateUserPinByPhone(
        _foundUser.phone,
        _pinController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN for ${_foundUser.name} updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Security Reset',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textSlate,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Painter PIN',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textSlate,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a painter by their registered mobile number to issue a new security PIN.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSlateLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Search Box
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.85),
                    blurRadius: 16,
                    offset: const Offset(-7, -7),
                  ),
                  BoxShadow(
                    color: const Color(0xFFD1CCC4).withValues(alpha: 0.65),
                    blurRadius: 16,
                    offset: const Offset(7, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) {
                      if (v.length == 10) _searchUser();
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g. 9876543210',
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.adminAccent),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminAccent),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: _searchUser,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            if (_foundUser != null) ...[
              const SizedBox(height: 24),
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 14,
                      offset: const Offset(-6, -6),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
                      blurRadius: 14,
                      offset: const Offset(6, 6),
                    ),
                    BoxShadow(
                      color: AppColors.adminAccent.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.adminAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: AppColors.adminAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _foundUser.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSlate,
                            ),
                          ),
                          Text(
                            _foundUser.businessName ?? 'No Business Name',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSlateLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _foundUser.status == 'active'
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                        : const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Reset PIN Form
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDE8),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.85),
                        blurRadius: 14,
                        offset: const Offset(-6, -6),
                      ),
                      BoxShadow(
                        color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
                        blurRadius: 14,
                        offset: const Offset(6, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Credentials',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSlate,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'New 4-Digit PIN',
                          hintText: 'Enter 4 numbers',
                          prefixIcon: Icon(Icons.lock_reset_rounded, color: AppColors.adminAccent),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter a PIN';
                          if (v.length != 4) return 'PIN must be exactly 4 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isResetting ? null : _handleReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isResetting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Confirm PIN Reset',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
