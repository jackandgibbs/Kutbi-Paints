import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/order_model.dart';
import '../../models/return_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';

// ============================================================================
// ReturnRequestScreen — multi-step return flow
// Step 1: Select items & quantities
// Step 2: Choose reason
// Step 3: Confirm & submit
// ============================================================================
class ReturnRequestScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ReturnRequestScreen({super.key, required this.orderId});

  @override
  ConsumerState<ReturnRequestScreen> createState() =>
      _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends ConsumerState<ReturnRequestScreen> {
  int _step = 0; // 0=items, 1=reason, 2=confirm, 3=success
  bool _isSubmitting = false;

  // Step 1 state
  final Map<int, bool> _selected = {}; // itemIndex → selected?
  final Map<int, int> _quantities = {}; // itemIndex → qty to return

  // Step 2 state
  String _reason = kReturnReasons.first;
  final _descCtrl = TextEditingController();

  // Step 3 result
  String? _submittedReturnId;
  String? _submittedReturnDisplayId;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final order = ds.getOrderById(widget.orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Return Order')),
        body: const Center(child: Text('Order not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _step == 3 ? 'Return Submitted' : 'Return Order',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: _step == 3
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  if (_step == 0) {
                    context.pop();
                  } else {
                    setState(() => _step--);
                  }
                },
              ),
        automaticallyImplyLeading: _step < 3,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 0
                ? _buildItemSelection(order, ds)
                : _step == 1
                    ? _buildReasonStep(order)
                    : _step == 2
                        ? _buildConfirmStep(order)
                        : _buildSuccessStep(),
          ),
        ),
      ),
    );
  }

  // ─── Step 1: Item Selection ───────────────────────────────────────────────

  Widget _buildItemSelection(OrderModel order, DataService ds) {
    final selectedItems = _selected.entries
        .where((e) => e.value && (_quantities[e.key] ?? 0) > 0)
        .toList();

    return Column(
      children: [
        _stepIndicator(0),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select items to return',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ...order.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final alreadyReturned =
                      ds.getAlreadyReturnedQuantity(order.id, idx);
                  final available = item.quantity - alreadyReturned;
                  final isAvailable = available > 0;
                  final isSelected = _selected[idx] == true;

                  return _buildItemCard(
                    item: item,
                    index: idx,
                    available: available,
                    alreadyReturned: alreadyReturned,
                    isAvailable: isAvailable,
                    isSelected: isSelected,
                  );
                }),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          label: 'Next: Choose Reason',
          enabled: selectedItems.isNotEmpty,
          onTap: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _buildItemCard({
    required OrderItemModel item,
    required int index,
    required int available,
    required int alreadyReturned,
    required bool isAvailable,
    required bool isSelected,
  }) {
    final maxQty = available;
    _quantities.putIfAbsent(index, () => 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Checkbox(
            value: isSelected && isAvailable,
            onChanged: isAvailable
                ? (v) => setState(() {
                      _selected[index] = v == true;
                      if (v == true) {
                        _quantities[index] = _quantities[index]!
                            .clamp(1, maxQty);
                      }
                    })
                : null,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAvailable
                        ? AppColors.textPrimary
                        : AppColors.textLight,
                  ),
                ),
                Text(
                  '${item.bucketSize} • ${item.colorName}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (alreadyReturned > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$alreadyReturned already returned · $available remaining',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!isAvailable && alreadyReturned == 0)
                  Text(
                    'Not available for return',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.error,
                    ),
                  ),
                // Quantity picker (visible when selected and qty > 1)
                if (isSelected && isAvailable && item.quantity > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Return quantity:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _QtyButton(
                        icon: Icons.remove_rounded,
                        enabled: (_quantities[index] ?? 1) > 1,
                        onTap: () => setState(() {
                          _quantities[index] =
                              ((_quantities[index] ?? 1) - 1).clamp(1, maxQty);
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_quantities[index] ?? 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QtyButton(
                        icon: Icons.add_rounded,
                        enabled: (_quantities[index] ?? 1) < maxQty,
                        onTap: () => setState(() {
                          _quantities[index] =
                              ((_quantities[index] ?? 1) + 1).clamp(1, maxQty);
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ $maxQty purchased',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Price
          Text(
            '₹${item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : "-"}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Reason ───────────────────────────────────────────────────────

  Widget _buildReasonStep(OrderModel order) {
    return Column(
      children: [
        _stepIndicator(1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you returning?',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...kReturnReasons.map((r) {
                  final selected = _reason == r;
                  return GestureDetector(
                    onTap: () => setState(() => _reason = r),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                              color: selected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            r,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  'Additional details (optional)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _reason == 'Other'
                        ? 'Please describe the issue...'
                        : 'Any additional details (optional)',
                    hintStyle: GoogleFonts.poppins(
                        color: AppColors.textLight, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          label: 'Next: Review & Confirm',
          enabled: _reason.isNotEmpty &&
              (_reason != 'Other' || _descCtrl.text.isNotEmpty),
          onTap: () => setState(() => _step = 2),
        ),
      ],
    );
  }

  // ─── Step 3: Confirm ──────────────────────────────────────────────────────

  Widget _buildConfirmStep(OrderModel order) {
    final selectedEntries = _selected.entries
        .where((e) => e.value && (_quantities[e.key] ?? 0) > 0)
        .toList();

    double estimatedRefund = 0;
    for (final e in selectedEntries) {
      final item = order.items[e.key];
      estimatedRefund += item.unitPrice * (_quantities[e.key] ?? 1);
    }

    return Column(
      children: [
        _stepIndicator(2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order info
                _sectionCard(
                  title: 'Order',
                  child: Column(
                    children: [
                      _row('Order #', order.id.substring(0, 8).toUpperCase()),
                      _row(
                          'Order Date',
                          DateFormat('dd MMM yyyy')
                              .format(order.createdAt)),
                      _row(
                          'Delivered',
                          DateFormat('dd MMM yyyy')
                              .format(order.updatedAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Items
                _sectionCard(
                  title: 'Items to Return',
                  child: Column(
                    children: selectedEntries.map((e) {
                      final item = order.items[e.key];
                      final qty = _quantities[e.key] ?? 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${item.bucketSize} · Qty: $qty',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.unitPrice > 0
                                  ? '₹${(item.unitPrice * qty).toStringAsFixed(0)}'
                                  : '-',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Reason
                _sectionCard(
                  title: 'Reason',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reason,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_descCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _descCtrl.text,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Refund estimate
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Refund',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            estimatedRefund > 0
                                ? '₹${estimatedRefund.toStringAsFixed(0)}'
                                : 'To be determined',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white54, size: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Refund method: Original Payment Method',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          label: _isSubmitting ? 'Submitting…' : 'Submit Return Request',
          enabled: !_isSubmitting,
          onTap: _submit,
          isPrimary: true,
        ),
      ],
    );
  }

  // ─── Step 4: Success ──────────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Return Request Submitted!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your return request has been received and is under review.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_submittedReturnDisplayId != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _row('Return ID', _submittedReturnDisplayId!),
                    _row('Order ID', widget.orderId.substring(0, 8).toUpperCase()),
                    _row('Status', 'Return Requested'),
                    _row(
                      'Requested',
                      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_submittedReturnId != null) {
                    context.go('/painter/return-tracking/$_submittedReturnId');
                  } else {
                    context.go('/painter/my-returns');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Track Return',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/painter/my-returns'),
              child: Text(
                'View All Returns',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _stepIndicator(int currentStep) {
    final steps = ['Select Items', 'Reason', 'Confirm'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done || active
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : AppColors.textLight,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    steps[i],
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < steps.length - 1)
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: Colors.grey.shade300),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: AppColors.textLight,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final ds = ref.read(dataServiceProvider);
    final user = ref.read(authProvider).user;

    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final order = ds.getOrderById(widget.orderId);
    if (order == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final selectedEntries = _selected.entries
        .where((e) => e.value && (_quantities[e.key] ?? 0) > 0)
        .toList();

    final itemsData = selectedEntries.map((e) {
      final idx = e.key;
      final item = order.items[idx];
      return {
        'itemIndex': idx,
        'productId': item.productId,
        'productName': item.productName,
        'bucketSize': item.bucketSize,
        'unitPrice': item.unitPrice,
        'colorName': item.colorName,
        'colorHex': item.colorHex,
        'quantity': _quantities[idx] ?? 1,
        'reason': null,
        'condition': 'unknown',
      };
    }).toList();

    try {
      final created = await ds.createReturnRequest(
        orderId: widget.orderId,
        userId: user.id,
        reason: _reason,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        items: itemsData,
      );
      setState(() {
        _submittedReturnId = created.id;
        _submittedReturnDisplayId = created.displayId;
        _step = 3;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit return: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ─── Small quantity button widget ─────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textLight,
        ),
      ),
    );
  }
}
