import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/data_service.dart';
import '../../../core/services/haptic_service.dart';

class ChatComingSoonView extends ConsumerWidget {
  const ChatComingSoonView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon / Illustration
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_rounded,
                size: 80,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 32),
            
            // Text
            Text(
              'Chat Coming Soon!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our in-app chat is under maintenance. Please contact our support team directly via WhatsApp for any assistance.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            
            // Action Button
            ElevatedButton.icon(
              onPressed: () {
                HapticService.medium();
                _showAdminWhatsAppPicker(context, ref);
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text('Contact on WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminWhatsAppPicker(BuildContext context, WidgetRef ref) {
    final ds = ref.read(dataServiceProvider);
    final admins = ds.getAdmins();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Admin to Chat',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              if (admins.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No admins currently available.',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: admins.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final admin = admins[index];
                      return ListTile(
                        onTap: () async {
                          HapticService.light();
                          final phone = admin.phone;
                          final url = 'https://wa.me/$phone?text=Hello ${admin.name}, I need assistance with Kutbi Paints admin app.';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch WhatsApp')),
                              );
                            }
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: Text(
                          admin.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          admin.phone,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
