import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _qrUrlCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _updateUrlCtrl = TextEditingController();
  bool _forceUpdateEnabled = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final ds = ref.read(dataServiceProvider);
    _qrUrlCtrl.text = ds.adminQrUrl;
    _minVersionCtrl.text = ds.minAppVersion;
    _updateUrlCtrl.text = ds.forceUpdateUrl;
    _forceUpdateEnabled = ds.forceUpdateEnabled;
  }

  @override
  void dispose() {
    _qrUrlCtrl.dispose();
    _minVersionCtrl.dispose();
    _updateUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final extension = ext.isNotEmpty ? ext : 'png';
      final fileName = 'admin_qr_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storagePath = 'admin/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('paint-images')
          .uploadBinary(
            storagePath, 
            bytes, 
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg')
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('paint-images')
          .getPublicUrl(storagePath);

      _qrUrlCtrl.text = publicUrl;
      setState(() => _isUploading = false);

      // Auto-save
      _save();
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _save() async {
    try {
      final ds = ref.read(dataServiceProvider);
      
      // Save Admin QR
      await ds.updateAdminQr(_qrUrlCtrl.text.trim());
      
      // Save Version Settings
      await ds.updateGlobalSettings(
        forceUpdate: _forceUpdateEnabled, 
        url: _updateUrlCtrl.text.trim(), 
        minVersion: _minVersionCtrl.text.trim()
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All settings updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Store Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Configuration',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure the QR code that painters see for online payments.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admin QR Code',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (_isUploading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminPrimary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Image Preview & Upload Button
                  Center(
                    child: Column(
                      children: [
                        if (_qrUrlCtrl.text.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _qrUrlCtrl.text,
                                height: 200,
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 200,
                                  width: 200,
                                  color: Colors.grey.shade100,
                                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 200,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No QR Code',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUploadImage,
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: Text(_qrUrlCtrl.text.isEmpty ? 'Upload QR Code' : 'Change QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.adminPrimary,
                            elevation: 0,
                            side: BorderSide(color: AppColors.adminPrimary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'Notification Settings',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure your phone allows the app to send alerts for new orders and bills.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await NotificationService.requestPermissions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification permission requested')),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 18),
                    label: const Text('Allow Alerts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await NotificationService.showOrderUpdate(
                        orderId: 'TEST_ID', 
                        status: 'accepted', 
                        brand: 'Kutbi Paints'
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Test Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      elevation: 0,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'App Version Control',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Force users to update if their app version is too old.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Enable Force Update', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Users will be blocked until they update', style: GoogleFonts.poppins(fontSize: 11)),
                    value: _forceUpdateEnabled,
                    activeColor: AppColors.adminPrimary,
                    onChanged: (val) => setState(() => _forceUpdateEnabled = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: _minVersionCtrl,
                    decoration: InputDecoration(
                      labelText: 'Minimum Required Version',
                      hintText: 'e.g. 1.0.5',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _updateUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Update Download URL',
                      hintText: 'Link to new APK or Play Store',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save Settings',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            Text(
              'Help & Instructions',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            _instructionText('1. Tap the "Upload QR Code" or "Change QR Code" button.'),
            _instructionText('2. Select a valid image from your device gallery. (JPEG/PNG)'),
            _instructionText('3. The image will be uploaded directly to the secure storage.'),
            _instructionText('4. Painter apps will see the updated QR instantly during checkout.'),
            _instructionText('5. Use "Force Update" only when a critical new version is released.'),
            const SizedBox(height: 32),
            
            Text(
              'Stickers & Promotions',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/admin/qr-generator');
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                label: Text(
                  'QR Sticker Generator',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.adminPrimary,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.adminPrimary.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _instructionText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
