import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../core/utils/responsive.dart';
import '../shared/widgets/user_avatar.dart';

class PainterProfileScreen extends ConsumerWidget {
  const PainterProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    // Watch DS so the bank status chip updates live (e.g. after admin approves)
    final liveUser = ref.watch(dataServiceProvider).getUserById(user?.id ?? '') ?? user;
    if (liveUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.go('/painter'),
                            icon: const Icon(Icons.arrow_back_ios_rounded,
                                color: Colors.white),
                          ),
                          const Spacer(),
                          Text('My Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),
                      UserAvatar(
                        imageUrl: liveUser.profileImageUrl,
                        name: liveUser.name,
                        size: 80,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        fontSize: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(liveUser.name,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                      if (liveUser.businessName != null)
                        Text(liveUser.businessName!,
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _infoTile(Icons.phone_rounded, 'Phone', liveUser.phone),
                      _infoTile(Icons.email_rounded, 'Email', liveUser.email),
                      if (liveUser.businessAddress != null)
                        _infoTile(Icons.location_on_rounded, 'Address',
                            liveUser.businessAddress!),
                      _infoTile(
                          Icons.workspace_premium_rounded,
                          'Tier',
                          liveUser.tier.toUpperCase()),
                      _bankDetailsTile(context, liveUser.bankStatus),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon:
                              const Icon(Icons.logout_rounded, color: Colors.white),
                          label: Text('Logout',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bankDetailsTile(BuildContext context, String bankStatus) {
    final (statusColor, statusLabel) = switch (bankStatus) {
      'approved' => (const Color(0xFF10B981), 'Approved'),
      'pending'  => (const Color(0xFFF59E0B), 'Pending review'),
      'rejected' => (AppColors.error, 'Rejected — resubmit'),
      _          => (AppColors.textLight, 'Not submitted'),
    };

    return GestureDetector(
      onTap: () => context.push('/painter/bank-details'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: bankStatus == 'rejected'
              ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank Details',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(statusLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: bankStatus == 'none'
                            ? AppColors.textSecondary
                            : statusColor,
                      )),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                bankStatus == 'approved'
                    ? Icons.check_circle_rounded
                    : bankStatus == 'pending'
                        ? Icons.hourglass_top_rounded
                        : bankStatus == 'rejected'
                            ? Icons.error_rounded
                            : Icons.arrow_forward_ios_rounded,
                color: statusColor,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
