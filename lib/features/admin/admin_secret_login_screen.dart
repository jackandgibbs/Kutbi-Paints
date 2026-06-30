import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class AdminSecretLoginScreen extends StatefulWidget {
  const AdminSecretLoginScreen({super.key});

  @override
  State<AdminSecretLoginScreen> createState() => _AdminSecretLoginScreenState();
}

class _AdminSecretLoginScreenState extends State<AdminSecretLoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String? _error;

  final String _secretUser = "30912846";
  final String _secretPass = "30921069";

  void _handleLogin() {
    if (_userController.text == _secretUser && _passController.text == _secretPass) {
      context.go('/admin-dashboard');
    } else {
      setState(() {
        _error = "Invalid Administrative Credentials";
      });
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'System Access',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.security_rounded, size: 60, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Terminal Login',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _userController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Access ID',
                prefixIcon: Icon(Icons.perm_identity_rounded),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Access Key',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
              onSubmitted: (_) => _handleLogin(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Authorize',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
