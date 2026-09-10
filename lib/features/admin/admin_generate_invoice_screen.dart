import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_support.dart';
import '../../core/utils/responsive.dart';
import '../../models/custom_invoice_model.dart';
import '../../models/product_model.dart';
import '../../services/bill_export_service.dart';
import '../../services/custom_invoice_service.dart';
import '../../services/data_service.dart';

class AdminGenerateInvoiceScreen extends ConsumerStatefulWidget {
  const AdminGenerateInvoiceScreen({super.key});

  @override
  ConsumerState<AdminGenerateInvoiceScreen> createState() =>
      _AdminGenerateInvoiceScreenState();
}

class _ItemRowController {
  final TextEditingController nameController;
  final TextEditingController sizeController;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  ProductModel? selectedProduct;

  _ItemRowController({
    String name = '',
    String size = '1L',
    int qty = 1,
    double rate = 0.0,
    this.selectedProduct,
  })  : nameController = TextEditingController(text: name),
        sizeController = TextEditingController(text: size),
        qtyController = TextEditingController(text: qty.toString()),
        rateController = TextEditingController(
            text: rate > 0 ? rate.toStringAsFixed(0) : '');

  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get rate => double.tryParse(rateController.text) ?? 0.0;
  double get total => quantity * rate;

  void dispose() {
    nameController.dispose();
    sizeController.dispose();
    qtyController.dispose();
    rateController.dispose();
  }
}

class _AdminGenerateInvoiceScreenState
    extends ConsumerState<AdminGenerateInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form state
  String _billType = 'purchase'; // 'purchase' or 'return'
  String? _selectedPainterId;
  final _painterNameController = TextEditingController();
  final _painterPhoneController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _editingInvoiceId;

  final List<_ItemRowController> _items = [];

  // Filter / Search state for Recently Generated tab
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'purchase', 'return'
  String _sortOption = 'newest'; // 'newest', 'oldest', 'amount_high', 'amount_low'
  DateTime? _filterDate;

  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addItemRow();

    // Generate initial invoice number after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_invoiceNoController.text.isEmpty) {
        final service = ref.read(customInvoiceServiceProvider);
        _invoiceNoController.text = service.generateInvoiceNumber(_billType);
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _painterNameController.dispose();
    _painterPhoneController.dispose();
    _invoiceNoController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItemRow({
    String name = '',
    String size = '1L',
    int qty = 1,
    double rate = 0.0,
    ProductModel? product,
  }) {
    final row = _ItemRowController(
      name: name,
      size: size,
      qty: qty,
      rate: rate,
      selectedProduct: product,
    );
    row.qtyController.addListener(() => setState(() {}));
    row.rateController.addListener(() => setState(() {}));
    setState(() => _items.add(row));
  }

  void _removeItemRow(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      _editingInvoiceId = null;
      _selectedPainterId = null;
      _painterNameController.clear();
      _painterPhoneController.clear();
      _discountController.text = '0';
      _notesController.clear();
      _selectedDate = DateTime.now();

      for (final item in _items) {
        item.dispose();
      }
      _items.clear();
      _addItemRow();

      final service = ref.read(customInvoiceServiceProvider);
      _invoiceNoController.text = service.generateInvoiceNumber(_billType);
    });
  }

  void _loadInvoiceForEdit(CustomInvoiceModel invoice) {
    setState(() {
      _editingInvoiceId = invoice.id;
      _billType = invoice.billType;
      _selectedPainterId = invoice.painterId;
      _painterNameController.text = invoice.painterName;
      _painterPhoneController.text = invoice.painterPhone;
      _invoiceNoController.text = invoice.invoiceNumber;
      _discountController.text = invoice.discount.toStringAsFixed(0);
      _notesController.text = invoice.notes;
      _selectedDate = invoice.date;

      for (final item in _items) {
        item.dispose();
      }
      _items.clear();

      final ds = ref.read(dataServiceProvider);
      for (final it in invoice.items) {
        ProductModel? prod;
        try {
          prod = ds.products.firstWhere(
            (p) => p.name.toLowerCase() == it.productName.toLowerCase(),
          );
        } catch (_) {}

        _addItemRow(
          name: it.productName,
          size: it.bucketSize,
          qty: it.quantity,
          rate: it.rate,
          product: prod,
        );
      }

      if (_items.isEmpty) {
        _addItemRow();
      }
    });

    // Switch to tab 0
    _tabController.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${invoice.invoiceNumber} for editing/customization'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.adminAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double get _subtotal {
    return _items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _totalAmount {
    final sub = _subtotal;
    final disc = _discount;
    final total = sub - disc;
    return total > 0 ? total : 0.0;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF97316),
              onPrimary: Colors.white,
              onSurface: AppColors.textSlate,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _generateAndPrintBill() async {
    final painterName = _painterNameController.text.trim();
    if (painterName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a painter / customer name'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate items
    final validItems = <CustomInvoiceItem>[];
    for (final it in _items) {
      final name = it.nameController.text.trim();
      if (name.isNotEmpty) {
        validItems.add(
          CustomInvoiceItem(
            productName: name,
            bucketSize: it.sizeController.text.trim(),
            quantity: it.quantity,
            rate: it.rate,
            amount: it.total,
          ),
        );
      }
    }

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product item with a name'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final invoiceId = _editingInvoiceId ?? const Uuid().v4();
      final invoice = CustomInvoiceModel(
        id: invoiceId,
        invoiceNumber: _invoiceNoController.text.trim().isNotEmpty
            ? _invoiceNoController.text.trim()
            : 'INV-1001',
        billType: _billType,
        painterId: _selectedPainterId,
        painterName: painterName,
        painterPhone: _painterPhoneController.text.trim(),
        date: _selectedDate,
        items: validItems,
        subtotal: _subtotal,
        discount: _discount,
        totalAmount: _totalAmount,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save or update in service
      final invoiceService = ref.read(customInvoiceServiceProvider);
      if (_editingInvoiceId != null) {
        await invoiceService.updateInvoice(invoice);
      } else {
        await invoiceService.addInvoice(invoice);
      }

      // Generate PDF
      final pdfBytes = await BillExportService.generateCustomInvoicePdf(invoice);

      if (!mounted) return;

      // Print / Preview via layoutPdf
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${invoice.invoiceNumber}_${invoice.painterName.replaceAll(' ', '_')}.pdf',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invoice ${invoice.invoiceNumber} generated & saved!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('VIEW LIST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // Reset form to next invoice
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating bill: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      appBar: AppBar(
        backgroundColor: AppColors.adminCardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSlate),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Generate Invoice',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textSlate,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: AppColors.textSlateLight,
          indicatorColor: const Color(0xFFF97316),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(
              icon: Icon(Icons.note_add_rounded, size: 20),
              text: 'Create Invoice',
            ),
            Tab(
              icon: Icon(Icons.history_rounded, size: 20),
              text: 'Recently Generated',
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreateInvoiceTab(isDesktop),
            _buildRecentlyGeneratedTab(isDesktop),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: CREATE INVOICE FORM
  // ===========================================================================
  Widget _buildCreateInvoiceTab(bool isDesktop) {
    final ds = ref.watch(dataServiceProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.horizontalPadding(context),
        20,
        Responsive.horizontalPadding(context),
        isDesktop ? 40 : 120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Editing banner if modifying an existing bill
              if (_editingInvoiceId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Currently customizing: ${_invoiceNoController.text}. Changes will update this bill.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF92400E)),
                        onPressed: _resetForm,
                        tooltip: 'Cancel customization & start new',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Bill Type Selector
              _buildSectionTitle('1. BILL TYPE'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildBillTypeToggle(
                      type: 'purchase',
                      label: 'Purchase Bill / Estimate',
                      icon: Icons.shopping_bag_outlined,
                      activeColor: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBillTypeToggle(
                      type: 'return',
                      label: 'Return / Credit Note',
                      icon: Icons.keyboard_return_rounded,
                      activeColor: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Party Details & Date
              _buildSectionTitle('2. CUSTOMER & DATE DETAILS'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    // Painter picker dropdown from registered painters
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedPainterId,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              labelText: 'Select Registered Painter (Optional)',
                              prefixIcon: Icons.badge_outlined,
                            ),
                            hint: Text(
                              'Choose from ${ds.painters.length} painters',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Custom / Walk-in Customer'),
                              ),
                              ...ds.painters.map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (${p.phone})',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedPainterId = val;
                                if (val != null) {
                                  try {
                                    final p = ds.painters.firstWhere((user) => user.id == val);
                                    _painterNameController.text = p.name;
                                    _painterPhoneController.text = p.phone;
                                  } catch (_) {}
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Manual Painter Name & Phone
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _painterNameController,
                            decoration: _inputDecoration(
                              labelText: 'Painter / Customer Name *',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _painterPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icons.phone_outlined,
                            ),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date & Invoice Number
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                labelText: 'Invoice Date',
                                prefixIcon: Icons.calendar_today_rounded,
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceNoController,
                            decoration: _inputDecoration(
                              labelText: 'Invoice / Ref No.',
                              prefixIcon: Icons.tag_rounded,
                            ),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Products & Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('3. PRODUCTS & QUANTITIES'),
                  ElevatedButton.icon(
                    onPressed: () => _addItemRow(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Item rows
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(index, item, ds.products);
              }),
              const SizedBox(height: 16),

              // Discounts and Notes
              _buildSectionTitle('4. ADJUSTMENTS & NOTES'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(
                              labelText: 'Discount / Adjustment (₹)',
                              prefixIcon: Icons.discount_outlined,
                            ),
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _notesController,
                            decoration: _inputDecoration(
                              labelText: 'Notes / Remarks (Optional)',
                              prefixIcon: Icons.edit_note_rounded,
                            ),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Financial Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryLine('Subtotal', '₹ ${_subtotal.toStringAsFixed(0)}', Colors.white70),
                    if (_discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryLine('Discount', '- ₹ ${_discount.toStringAsFixed(0)}', const Color(0xFF34D399)),
                    ],
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _billType == 'purchase' ? 'Grand Total' : 'Net Refund Amount',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          '₹ ${_totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _billType == 'purchase' ? const Color(0xFF38BDF8) : const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset Form'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSlate,
                      side: const BorderSide(color: AppColors.adminBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _generateAndPrintBill,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.print_rounded, size: 20),
                      label: Text(
                        _isGeneratingPdf
                            ? 'Generating PDF...'
                            : (_editingInvoiceId != null ? 'Update & Print Bill' : 'Generate & Print Bill'),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _billType == 'purchase' ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillTypeToggle({
    required String type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _billType == type;

    return GestureDetector(
      onTap: () {
        if (PlatformSupport.supportsHaptics) HapticFeedback.selectionClick();
        setState(() {
          _billType = type;
          // Refresh invoice prefix if not currently editing
          if (_editingInvoiceId == null) {
            final service = ref.read(customInvoiceServiceProvider);
            _invoiceNoController.text = service.generateInvoiceNumber(type);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : AppColors.adminCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.adminBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? activeColor : AppColors.textSlateLight, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : AppColors.textSlate,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _ItemRowController item, List<ProductModel> products) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Item # and Remove
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item #${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSlateLight,
                  letterSpacing: 0.5,
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeItemRow(index),
                  tooltip: 'Remove Item',
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Select or Input
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductModel?>(
                  // ignore: deprecated_member_use
                  value: item.selectedProduct,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    labelText: 'Select From Catalog (Optional)',
                    prefixIcon: Icons.format_paint_outlined,
                  ),
                  hint: Text('Catalog Product', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight)),
                  items: [
                    const DropdownMenuItem<ProductModel?>(
                      value: null,
                      child: Text('Custom / Other Product'),
                    ),
                    ...products.map((p) => DropdownMenuItem<ProductModel?>(
                          value: p,
                          child: Text(
                            '${p.name} (${p.brand})',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        )),
                  ],
                  onChanged: (prod) {
                    setState(() {
                      item.selectedProduct = prod;
                      if (prod != null) {
                        item.nameController.text = prod.name;
                        if (prod.bucketSizes.isNotEmpty) {
                          item.sizeController.text = prod.bucketSizes.first;
                          final price = prod.prices[prod.bucketSizes.first] ?? 0.0;
                          if (price > 0) {
                            item.rateController.text = price.toStringAsFixed(0);
                          }
                        }
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Name (editable) & Size
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: item.nameController,
                  decoration: _inputDecoration(labelText: 'Product Name *'),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: item.selectedProduct != null && item.selectedProduct!.bucketSizes.isNotEmpty
                    ? DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: item.selectedProduct!.bucketSizes.contains(item.sizeController.text)
                            ? item.sizeController.text
                            : item.selectedProduct!.bucketSizes.first,
                        decoration: _inputDecoration(labelText: 'Size'),
                        items: item.selectedProduct!.bucketSizes
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13))))
                            .toList(),
                        onChanged: (s) {
                          if (s != null) {
                            setState(() {
                              item.sizeController.text = s;
                              final pr = item.selectedProduct!.prices[s];
                              if (pr != null && pr > 0) {
                                item.rateController.text = pr.toStringAsFixed(0);
                              }
                            });
                          }
                        },
                      )
                    : TextFormField(
                        controller: item.sizeController,
                        decoration: _inputDecoration(labelText: 'Size (e.g. 4L, 20L)'),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Quantity (Left) & Rate / MRP (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity stepper (enlarged with equal size for -, number, +)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.adminBorder),
                      ),
                      child: Row(
                        children: [
                          // Minus button (equal 1/3 size)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  item.qtyController.text = (item.quantity - 1).toString();
                                }
                              },
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border(right: BorderSide(color: AppColors.adminBorder)),
                                ),
                                child: const Icon(Icons.remove_rounded, size: 20, color: AppColors.textSlate),
                              ),
                            ),
                          ),
                          // Number box (equal 1/3 size, clearly readable)
                          Expanded(
                            child: TextFormField(
                              controller: item.qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSlate,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                          // Plus button (equal 1/3 size)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                item.qtyController.text = (item.quantity + 1).toString();
                              },
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border(left: BorderSide(color: AppColors.adminBorder)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 20, color: AppColors.textSlate),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Rate / MRP input (enlarged)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate / MRP (₹)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: item.rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration(
                          labelText: '',
                          prefixIcon: Icons.currency_rupee_rounded,
                        ).copyWith(
                          hintText: '0',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Calculated Amount (Below)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.adminBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, size: 16, color: AppColors.textSlateLight),
                    const SizedBox(width: 6),
                    Text(
                      'Item Total (${item.quantity} x ₹${item.rate.toStringAsFixed(0)})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹ ${item.total.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: color)),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: RECENTLY GENERATED INVOICES
  // ===========================================================================
  Widget _buildRecentlyGeneratedTab(bool isDesktop) {
    final invoiceService = ref.watch(customInvoiceServiceProvider);
    final allInvoices = invoiceService.invoices;

    // Filter by search query
    var filtered = allInvoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final matchNo = inv.invoiceNumber.toLowerCase().contains(_searchQuery);
      final matchName = inv.painterName.toLowerCase().contains(_searchQuery);
      final matchPhone = inv.painterPhone.toLowerCase().contains(_searchQuery);
      final matchItem = inv.items.any((i) => i.productName.toLowerCase().contains(_searchQuery));
      return matchNo || matchName || matchPhone || matchItem;
    }).toList();

    // Filter by type
    if (_typeFilter != 'all') {
      filtered = filtered.where((inv) => inv.billType.toLowerCase() == _typeFilter).toList();
    }

    // Filter by date
    if (_filterDate != null) {
      filtered = filtered.where((inv) {
        return inv.date.year == _filterDate!.year &&
            inv.date.month == _filterDate!.month &&
            inv.date.day == _filterDate!.day;
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case 'oldest':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amount_high':
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'amount_low':
        filtered.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.horizontalPadding(context),
        20,
        Responsive.horizontalPadding(context),
        isDesktop ? 40 : 120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Invoice No, Painter, Phone, Product...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSlateLight),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.adminCardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Filter Chips & Sort row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Type Filters
                    _filterChip('All Types', 'all', _typeFilter, (val) => setState(() => _typeFilter = val)),
                    const SizedBox(width: 8),
                    _filterChip('Purchases', 'purchase', _typeFilter, (val) => setState(() => _typeFilter = val)),
                    const SizedBox(width: 8),
                    _filterChip('Returns', 'return', _typeFilter, (val) => setState(() => _typeFilter = val)),
                    const SizedBox(width: 14),

                    // Date Filter Chip
                    ActionChip(
                      avatar: Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: _filterDate != null ? Colors.white : AppColors.textSlate,
                      ),
                      label: Text(
                        _filterDate != null
                            ? DateFormat('dd MMM').format(_filterDate!)
                            : 'Date Filter',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _filterDate != null ? Colors.white : AppColors.textSlate,
                        ),
                      ),
                      backgroundColor: _filterDate != null ? const Color(0xFFF97316) : AppColors.adminCardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _filterDate != null ? const Color(0xFFF97316) : AppColors.adminBorder,
                        ),
                      ),
                      onPressed: () async {
                        if (_filterDate != null) {
                          setState(() => _filterDate = null);
                        } else {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _filterDate = picked);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),

                    // Sort menu
                    PopupMenuButton<String>(
                      initialValue: _sortOption,
                      onSelected: (val) => setState(() => _sortOption = val),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'newest', child: Text('Date: Newest First')),
                        const PopupMenuItem(value: 'oldest', child: Text('Date: Oldest First')),
                        const PopupMenuItem(value: 'amount_high', child: Text('Amount: High to Low')),
                        const PopupMenuItem(value: 'amount_low', child: Text('Amount: Low to High')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.adminCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.adminBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSlate),
                            const SizedBox(width: 6),
                            Text(
                              _sortOption == 'amount_high'
                                  ? '₹ High to Low'
                                  : _sortOption == 'amount_low'
                                      ? '₹ Low to High'
                                      : _sortOption == 'oldest'
                                          ? 'Oldest'
                                          : 'Newest',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSlate),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Count Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} Invoices Found',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSlateLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List of Invoices or Empty state
              if (filtered.isEmpty)
                _buildEmptyInvoicesState()
              else
                ...filtered.map((inv) => _buildInvoiceCard(inv)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSlate,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFF97316),
      backgroundColor: AppColors.adminCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFFF97316) : AppColors.adminBorder),
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  Widget _buildEmptyInvoicesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 16),
          Text(
            'No Invoices Found',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textSlate),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _typeFilter != 'all' || _filterDate != null
                ? 'Try adjusting your search terms or filters.'
                : 'No custom invoices have been generated yet.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Your First Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(CustomInvoiceModel invoice) {
    final isPurchase = invoice.isPurchase;
    final badgeColor = isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626);
    final badgeBg = isPurchase ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges, Invoice No, Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPurchase ? 'PURCHASE' : 'RETURN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    invoice.invoiceNumber,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSlate,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('dd MMM yyyy').format(invoice.date),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSlateLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Customer / Painter Info
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSlateLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.painterName,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSlate),
                ),
              ),
              if (invoice.painterPhone.isNotEmpty)
                Text(
                  invoice.painterPhone,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Items summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.adminBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${invoice.items.length} ${invoice.items.length == 1 ? 'item' : 'items'}: ${invoice.items.map((i) => '${i.productName} (${i.bucketSize}) x${i.quantity}').join(', ')}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (invoice.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${invoice.notes}',
                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSlateLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 22, color: AppColors.adminBorder),

          // Row 4: Total & Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPurchase ? 'Total Amount' : 'Refund Total',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlateLight),
                  ),
                  Text(
                    '₹ ${invoice.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isPurchase ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                tooltip: 'Delete Bill',
                onPressed: () => _confirmDeleteInvoice(invoice),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 5: Action Buttons (Customize & Regenerate)
          Row(
            children: [
              // Select / Customize Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _loadInvoiceForEdit(invoice),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Customize'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSlate,
                    side: const BorderSide(color: AppColors.adminBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Regenerate / Print Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final pdfBytes = await BillExportService.generateCustomInvoicePdf(invoice);
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes,
                        name: '${invoice.invoiceNumber}.pdf',
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error printing: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Regenerate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteInvoice(CustomInvoiceModel invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Invoice?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber} for ${invoice.painterName}? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(customInvoiceServiceProvider).deleteInvoice(invoice.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted invoice ${invoice.invoiceNumber}'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // HELPERS & STYLING
  // ===========================================================================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textSlateLight,
        letterSpacing: 0.8,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.adminCardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.adminBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.textSlateLight) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.adminBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.adminBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
    );
  }
}
