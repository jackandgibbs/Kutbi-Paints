import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';

class AddPainterScreen extends ConsumerStatefulWidget {
  const AddPainterScreen({super.key});

  @override
  ConsumerState<AddPainterScreen> createState() => _AddPainterScreenState();
}

class _AddPainterScreenState extends ConsumerState<AddPainterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _businessAddressCtrl = TextEditingController();
  String _tier = 'silver';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _businessNameCtrl.dispose();
    _businessAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePainter() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(dataServiceProvider).addPainter(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          pin: _pinCtrl.text.trim(),
          businessName: _businessNameCtrl.text.trim(),
          businessAddress: _businessAddressCtrl.text.trim(),
          tier: _tier,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Painter added successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text('Add Painter',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_nameCtrl, 'Full Name', Icons.person_rounded,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone', Icons.phone_rounded,
                  keyboard: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (v.length != 10) return 'Enter 10 digits';
                    return null;
                  }),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email', Icons.email_rounded,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) =>
                      v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(_pinCtrl, 'PIN', Icons.lock_rounded,
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (v.length != 4) return '4 digits required';
                    return null;
                  }),
              const SizedBox(height: 12),
              _field(_businessNameCtrl, 'Business Name',
                  Icons.business_rounded,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(_businessAddressCtrl, 'Business Address',
                  Icons.location_on_rounded,
                  maxLines: 2,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),

              // Tier selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 12,
                      offset: const Offset(-5, -5),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(5, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tier',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'silver',
                            groupValue: _tier,
                            onChanged: (v) =>
                                setState(() => _tier = v!),
                            title: Text('Silver',
                                style: GoogleFonts.poppins(fontSize: 13)),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'gold',
                            groupValue: _tier,
                            onChanged: (v) =>
                                setState(() => _tier = v!),
                            title: Text('Gold',
                                style: GoogleFonts.poppins(fontSize: 13)),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _savePainter,
                  child: Text('Add Painter',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
      validator: validator,
    );
  }
}
