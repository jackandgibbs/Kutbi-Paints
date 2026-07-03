import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';

class AdminBankDetailsScreen extends ConsumerStatefulWidget {
  const AdminBankDetailsScreen({super.key});

  @override
  ConsumerState<AdminBankDetailsScreen> createState() =>
      _AdminBankDetailsScreenState();
}

class _AdminBankDetailsScreenState
    extends ConsumerState<AdminBankDetailsScreen> {
  final Map<String, bool> _saving = {};

  Future<void> _approve(UserModel painter) async {
    setState(() => _saving[painter.id] = true);
    try {
      await ref.read(dataServiceProvider).updateBankStatus(painter.id, 'approved');
      await NotificationService.showBankDetailsApproved();
      if (mounted) {
        _snack('${painter.name}\'s bank details approved!', success: true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving[painter.id] = false);
    }
  }

  Future<void> _reject(UserModel painter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Bank Details?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          '${painter.name} will be notified to resubmit their bank details.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving[painter.id] = true);
    try {
      await ref.read(dataServiceProvider).updateBankStatus(painter.id, 'rejected');
      if (mounted) {
        _snack('${painter.name}\'s bank details rejected.');
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving[painter.id] = false);
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
    final ds = ref.watch(dataServiceProvider);

    // All painters, sorted: pending first, then alpha
    final painters = ds.painters.toList()
      ..sort((a, b) {
        final aP = a.bankStatus == 'pending' ? 0 : 1;
        final bP = b.bankStatus == 'pending' ? 0 : 1;
        if (aP != bP) return aP.compareTo(bP);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final pendingCount =
        painters.where((p) => p.bankStatus == 'pending').length;

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            size: 20),
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bank Details',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Review painter bank submissions',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pendingCount pending',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── List ────────────────────────────────────────────
              Expanded(
                child: painters.isEmpty
                    ? Center(
                        child: Text('No painters registered.',
                            style: GoogleFonts.poppins(
                                color: AppColors.textSecondary)),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: ds.refresh,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: painters.length,
                          itemBuilder: (context, i) {
                            final painter = painters[i];
                            return _BankPainterCard(
                              painter: painter,
                              isSaving: _saving[painter.id] == true,
                              onApprove: () => _approve(painter),
                              onReject: () => _reject(painter),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BankPainterCard extends StatefulWidget {
  final UserModel painter;
  final bool isSaving;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BankPainterCard({
    required this.painter,
    required this.isSaving,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_BankPainterCard> createState() => _BankPainterCardState();
}

class _BankPainterCardState extends State<_BankPainterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final painter = widget.painter;
    final status = painter.bankStatus;
    final hasPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hasPending
            ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Summary row ─────────────────────────────────────────
          InkWell(
            onTap: status == 'none'
                ? null
                : () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar with optional red dot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: painter.profileImageUrl != null
                            ? NetworkImage(painter.profileImageUrl!)
                            : null,
                        child: painter.profileImageUrl == null
                            ? Text(
                                painter.name.isNotEmpty
                                    ? painter.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      if (hasPending)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          painter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          painter.phone,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(status),
                  if (status != 'none') ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded detail ─────────────────────────────────────
          if (_expanded && status != 'none')
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7F5),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFE5E2DC)),
                    const SizedBox(height: 14),

                    // Account number
                    if (painter.bankAccountNumber != null) ...[
                      _detailRow(
                        Icons.account_balance_rounded,
                        'Account Number',
                        painter.bankAccountNumber!,
                        selectable: true,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Passbook image
                    if (painter.bankPassbookUrl != null) ...[
                      Text(
                        'Passbook / Cheque Photo',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            _showFullImage(context, painter.bankPassbookUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            painter.bankPassbookUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap image to view full size',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons (only for pending)
                    if (status == 'pending')
                      widget.isSaving
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: widget.onApprove,
                                    icon: const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18),
                                    label: Text('Approve',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: widget.onReject,
                                    icon: const Icon(Icons.cancel_rounded,
                                        size: 18),
                                    label: Text('Reject',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: BorderSide(
                                          color: AppColors.error
                                              .withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                    // Info text for approved/rejected
                    if (status == 'approved')
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Text('Bank details approved',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (status == 'rejected')
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cancel_rounded,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Text('Bank details rejected',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool selectable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary)),
              selectable
                  ? SelectableText(
                      value,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    )
                  : Text(
                      value,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
            ],
          ),
        ),
        if (selectable)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
              ));
            },
          ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String url) {
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
      'pending'  => (AppColors.error, 'Pending'),
      'rejected' => (const Color(0xFFF59E0B), 'Rejected'),
      _          => (AppColors.textLight, 'Not submitted'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
