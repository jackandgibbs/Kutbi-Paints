import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/data_service.dart';
import '../../models/order_model.dart';

class AdminCommissionsScreen extends ConsumerStatefulWidget {
  const AdminCommissionsScreen({super.key});

  @override
  ConsumerState<AdminCommissionsScreen> createState() => _AdminCommissionsScreenState();
}

class _AdminCommissionsScreenState extends ConsumerState<AdminCommissionsScreen> {
  // Keep controllers per order id so edits survive list rebuilds
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _saving = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(OrderModel order) {
    return _controllers.putIfAbsent(
      order.id,
      () => TextEditingController(
        text: order.commission > 0 ? order.commission.toStringAsFixed(0) : '',
      ),
    );
  }

  Future<void> _save(OrderModel order, double newCommission) async {
    setState(() => _saving[order.id] = true);
    try {
      await ref.read(dataServiceProvider).updateOrderCommission(order.id, newCommission);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commission updated to ₹${newCommission.toStringAsFixed(0)}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving[order.id] = false);
    }
  }

  Future<void> _reset(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Commission?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will set the commission for this order to ₹0.',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _ctrlFor(order).clear();
    await _save(order, 0);
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    // All billed orders (getAllOrders already excludes deletedByAdmin), newest first
    final allOrders = ds
        .getAllOrders()
        .where((o) => o.totalAmount > 0)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalCommission =
        allOrders.fold<double>(0, (s, o) => s + o.commission);

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────
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
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Commissions',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Edit painter commissions per order',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Total badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₹${totalCommission.toStringAsFixed(0)} total',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── List ───────────────────────────────────────────
              Expanded(
                child: allOrders.isEmpty
                    ? Center(
                        child: Text(
                          'No billed orders found.',
                          style: GoogleFonts.poppins(color: AppColors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF10B981),
                        onRefresh: ds.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: allOrders.length,
                          itemBuilder: (context, index) {
                            final order = allOrders[index];
                            final painterName =
                                ds.getUserById(order.painterId)?.name ?? 'Unknown';
                            return _CommissionCard(
                              order: order,
                              painterName: painterName,
                              ctrl: _ctrlFor(order),
                              isSaving: _saving[order.id] == true,
                              onSave: (val) => _save(order, val),
                              onReset: () => _reset(order),
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

class _CommissionCard extends StatelessWidget {
  final dynamic order;
  final String painterName;
  final TextEditingController ctrl;
  final bool isSaving;
  final ValueChanged<double> onSave;
  final VoidCallback onReset;

  const _CommissionCard({
    required this.order,
    required this.painterName,
    required this.ctrl,
    required this.isSaving,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final commission = (order.commission as double);
    final date = order.createdAt as DateTime;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: commission > 0
            ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${(order.id as String).substring(0, 8).toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: commission > 0
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  commission > 0 ? '₹${commission.toStringAsFixed(0)}' : '₹0',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: commission > 0
                        ? const Color(0xFF10B981)
                        : AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$painterName  •  ${order.brand}  •  $dateStr',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            'Bill total: ₹${(order.totalAmount as double).toStringAsFixed(0)}',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 14),

          // Commission input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0',
                    labelText: 'Commission Amount',
                    labelStyle: GoogleFonts.poppins(fontSize: 13),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              // Save button
              isSaving
                  ? const SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF10B981))),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(ctrl.text.trim()) ?? 0;
                        onSave(val);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(64, 42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Save',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    ),
              const SizedBox(width: 8),
              // Reset button
              IconButton(
                onPressed: isSaving ? null : onReset,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.error,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                tooltip: 'Reset to ₹0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
