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
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
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
  final TextEditingController shadeController;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  ProductModel? selectedProduct;

  _ItemRowController({
    String name = '',
    String size = '1L',
    String shade = '',
    int qty = 1,
    double rate = 0.0,
    this.selectedProduct,
  })  : nameController = TextEditingController(text: name),
        sizeController = TextEditingController(text: size),
        shadeController = TextEditingController(text: shade),
        qtyController = TextEditingController(text: qty.toString()),
        rateController = TextEditingController(
            text: rate > 0 ? rate.toStringAsFixed(0) : '');

  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get rate => double.tryParse(rateController.text) ?? 0.0;
  double get total => quantity * rate;

  void dispose() {
    nameController.dispose();
    sizeController.dispose();
    shadeController.dispose();
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
  String _orderStatus = 'placed'; // 'placed' (New), 'accepted', 'preparing', 'dispatched', 'delivered'
  String? _editingOrderId;
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
  String? _selectedRecentlyGeneratedUserKey;

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
    String shade = '',
    int qty = 1,
    double rate = 0.0,
    ProductModel? product,
  }) {
    final row = _ItemRowController(
      name: name,
      size: size,
      shade: shade,
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
      _editingOrderId = null;
      _orderStatus = 'placed';
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
      _editingOrderId = invoice.orderId;
      _orderStatus = (invoice.orderStatus != null && invoice.orderStatus!.isNotEmpty)
          ? invoice.orderStatus!
          : 'placed';
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
          shade: it.shade ?? '',
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
    final ds = ref.read(dataServiceProvider);
    String painterId = _selectedPainterId ?? '';
    final painterName = _painterNameController.text.trim();
    final phone = _painterPhoneController.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Auto-resolve painterId from registered users if not chosen directly from dropdown
    if (painterId.isEmpty) {
      if (cleanPhone.isNotEmpty) {
        final match = ds.users.where((p) {
          final pClean = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
          if (pClean.length >= 10 && cleanPhone.length >= 10) {
            return pClean.substring(pClean.length - 10) == cleanPhone.substring(cleanPhone.length - 10);
          }
          return pClean.isNotEmpty && pClean == cleanPhone;
        }).firstOrNull;
        if (match != null) painterId = match.id;
      }
      if (painterId.isEmpty && painterName.isNotEmpty) {
        final match = ds.users.where((p) =>
            !p.isAdmin && p.name.trim().toLowerCase() == painterName.toLowerCase()
        ).firstOrNull;
        if (match != null) painterId = match.id;
      }
    }

    if (painterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a registered painter before generating the invoice.'),
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
        if (it.quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid quantity for all items.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        validItems.add(
          CustomInvoiceItem(
            productName: name,
            bucketSize: it.sizeController.text.trim(),
            quantity: it.quantity,
            rate: it.rate,
            amount: it.total,
            shade: it.shadeController.text.trim().isNotEmpty ? it.shadeController.text.trim() : null,
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
      final orderId = _editingOrderId ?? const Uuid().v4();
      final statusToSave = _billType == 'purchase' ? _orderStatus : 'returned';

      final invoice = CustomInvoiceModel(
        id: invoiceId,
        invoiceNumber: _invoiceNoController.text.trim().isNotEmpty
            ? _invoiceNoController.text.trim()
            : 'INV-1001',
        billType: _billType,
        painterId: painterId,
        painterName: painterName,
        painterPhone: _painterPhoneController.text.trim(),
        date: _selectedDate,
        items: validItems,
        subtotal: _subtotal,
        discount: _discount,
        totalAmount: _totalAmount,
        notes: _notesController.text.trim(),
        orderId: orderId,
        orderStatus: statusToSave,
        createdAt: DateTime.now(),
      );

      final orderItems = validItems.map((it) {
        return OrderItemModel(
          productId: it.productName,
          productName: it.productName,
          colorCode: it.shade ?? '',
          colorName: it.shade ?? '',
          colorHex: '#2563EB',
          quantity: it.quantity,
          bucketSize: it.bucketSize.isNotEmpty ? it.bucketSize : 'Standard',
          unitPrice: it.rate,
          totalPrice: it.amount,
          shadeCode: it.shade,
        );
      }).toList();

      String brand = 'Asian Paints';
      final firstItemName = validItems.first.productName.toLowerCase();
      if (firstItemName.contains('nerolac')) {
        brand = 'Nerolac';
      } else if (firstItemName.contains('birla')) {
        brand = 'Birla Opus';
      } else if (ds.getAllBrands().isNotEmpty) {
        brand = ds.getAllBrands().first.name;
      }

      // Generate PDF first
      final pdfBytes = await BillExportService.generateCustomInvoicePdf(invoice);

      // Attempt to upload PDF to Supabase Storage for multi-device sync
      String? uploadedPdfUrl;
      try {
        uploadedPdfUrl = await ds.uploadBillPdf(orderId, pdfBytes, '${invoice.invoiceNumber}.pdf');
      } catch (e) {
        debugPrint('Note: PDF upload to storage skipped or failed: $e');
      }

      // Save order in DataService & Supabase
      final savedOrder = await ds.saveOrderFromAdminInvoice(
        existingOrderId: _editingOrderId ?? orderId,
        invoiceNumber: invoice.invoiceNumber,
        painterId: painterId,
        painterName: painterName,
        painterPhone: _painterPhoneController.text.trim(),
        brand: brand,
        items: orderItems,
        totalAmount: _totalAmount,
        subtotal: _subtotal,
        discountAmount: _discount,
        status: statusToSave,
        orderDate: _selectedDate,
        billImageUrl: uploadedPdfUrl,
      );

      // Save or update in custom invoice service
      final invoiceService = ref.read(customInvoiceServiceProvider);
      final finalInvoice = invoice.copyWith(
        orderId: savedOrder.id,
        orderStatus: savedOrder.status,
      );
      if (_editingInvoiceId != null) {
        await invoiceService.updateInvoice(finalInvoice);
      } else {
        await invoiceService.addInvoice(finalInvoice);
      }

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
                  'Invoice ${invoice.invoiceNumber} & Order #${savedOrder.id.substring(0, 8)} created!\nCustomer: $painterName • Total: ₹${_totalAmount.toStringAsFixed(0)} • Status: ${_billType == 'purchase' ? (_orderStatus == 'placed' ? 'New' : _orderStatus.toUpperCase()) : 'Returned'}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/admin/orders'),
                child: const Text('VIEW ORDERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          content: Text('Error generating bill & order: $e'),
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

    return PopScope(
      canPop: _selectedRecentlyGeneratedUserKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedRecentlyGeneratedUserKey != null) {
          setState(() => _selectedRecentlyGeneratedUserKey = null);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.adminBg,
        appBar: AppBar(
          backgroundColor: AppColors.adminCardBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSlate),
            onPressed: () {
              if (_selectedRecentlyGeneratedUserKey != null && _tabController.index == 1) {
                setState(() => _selectedRecentlyGeneratedUserKey = null);
              } else {
                context.pop();
              }
            },
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
      ),
    );
  }

  void _openPainterSearchDialog(List<UserModel> painters) async {
    final result = await showDialog<_PainterSelectionResult>(
      context: context,
      builder: (ctx) => _PainterSearchDialog(
        painters: painters,
        selectedPainterId: _selectedPainterId,
      ),
    );

    if (result != null) {
      if (result.isClear) {
        setState(() {
          _selectedPainterId = null;
        });
      } else if (result.painter != null) {
        setState(() {
          _selectedPainterId = result.painter!.id;
          _painterNameController.text = result.painter!.name;
          _painterPhoneController.text = result.painter!.phone;
        });
      }
    }
  }

  void _selectProductForItem(_ItemRowController item, ProductModel? prod) {
    setState(() {
      item.selectedProduct = prod;
      if (prod != null) {
        item.nameController.text = prod.name;
        if (prod.colorCode.isNotEmpty) {
          item.shadeController.text = prod.colorCode;
        } else if (prod.colorName.isNotEmpty) {
          item.shadeController.text = prod.colorName;
        }
        if (prod.bucketSizes.isNotEmpty) {
          item.sizeController.text = prod.bucketSizes.first;
          final price = prod.prices[prod.bucketSizes.first] ?? 0.0;
          if (price > 0) {
            item.rateController.text = price.toStringAsFixed(0);
          }
        }
      }
    });
  }

  void _openProductSearchDialog(_ItemRowController item, List<ProductModel> products) async {
    final result = await showDialog<_ProductSelectionResult>(
      context: context,
      builder: (ctx) => _ProductSearchDialog(
        products: products,
        selectedProductId: item.selectedProduct?.id,
      ),
    );

    if (result != null) {
      if (result.isClear) {
        setState(() {
          item.selectedProduct = null;
        });
      } else if (result.product != null) {
        _selectProductForItem(item, result.product);
      }
    }
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
                            value: (ds.users.any((u) => !u.isAdmin && u.id == _selectedPainterId))
                                ? _selectedPainterId
                                : null,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              labelText: 'Select Registered Painter *',
                              prefixIcon: Icons.badge_outlined,
                            ),
                            hint: Text(
                              'Choose from ${ds.users.where((u) => !u.isAdmin).length} registered painters',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
                            ),
                            items: [
                              ...ds.users.where((u) => !u.isAdmin).map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (${p.phone})',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedPainterId = val;
                                if (val != null) {
                                  try {
                                    final p = ds.users.firstWhere((user) => user.id == val);
                                    _painterNameController.text = p.name;
                                    _painterPhoneController.text = p.phone;
                                  } catch (_) {}
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Search Registered Painters',
                          child: InkWell(
                            onTap: () => _openPainterSearchDialog(
                              ds.users.where((u) => !u.isAdmin).toList(),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(
                                Icons.person_search_rounded,
                                color: Color(0xFFF97316),
                                size: 22,
                              ),
                            ),
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
                    if (_billType == 'purchase') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _orderStatus,
                        decoration: _inputDecoration(
                          labelText: 'Initial Order Status',
                          prefixIcon: Icons.local_shipping_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'placed',
                            child: Text('New (Placed)'),
                          ),
                          DropdownMenuItem(
                            value: 'accepted',
                            child: Text('Accepted'),
                          ),
                          DropdownMenuItem(
                            value: 'preparing',
                            child: Text('Preparing'),
                          ),
                          DropdownMenuItem(
                            value: 'dispatched',
                            child: Text('Dispatched'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Delivered'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _orderStatus = val);
                          }
                        },
                      ),
                    ],
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
                  value: (item.selectedProduct != null && products.any((p) => p.id == item.selectedProduct!.id))
                      ? products.firstWhere((p) => p.id == item.selectedProduct!.id)
                      : null,
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
                  onChanged: (prod) => _selectProductForItem(item, prod),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Search Catalog Products',
                child: InkWell(
                  onTap: () => _openProductSearchDialog(item, products),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFF97316),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Name (editable)
          TextFormField(
            controller: item.nameController,
            decoration: _inputDecoration(
              labelText: 'Product Name *',
              prefixIcon: Icons.format_paint_outlined,
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 10),

          // Size (Left) & Shade Field (Right)
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item.shadeController,
                  decoration: _inputDecoration(
                    labelText: 'Shade / Color Code',
                    prefixIcon: Icons.palette_outlined,
                  ),
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
    final ds = ref.watch(dataServiceProvider);
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

    // Group filtered invoices by user
    final Map<String, List<CustomInvoiceModel>> invoicesByUser = {};
    for (final inv in filtered) {
      final key = (inv.painterId != null && inv.painterId!.isNotEmpty)
          ? inv.painterId!
          : '${inv.painterName.trim().toLowerCase()}_${inv.painterPhone.trim()}';
      invoicesByUser.putIfAbsent(key, () => []).add(inv);
    }

    final userList = invoicesByUser.entries.map((entry) {
      final key = entry.key;
      final invoices = entry.value;
      final first = invoices.first;
      final user = (first.painterId != null && first.painterId!.isNotEmpty)
          ? ds.getUserById(first.painterId!)
          : null;
      final name = user?.name ?? first.painterName;
      final phone = user?.phone ?? first.painterPhone;
      final totalAmount = invoices.fold<double>(0.0, (sum, i) => sum + (i.isPurchase ? i.totalAmount : -i.totalAmount));
      final purchaseCount = invoices.where((i) => i.isPurchase).length;
      final returnCount = invoices.where((i) => !i.isPurchase).length;
      final latestDate = invoices.map((i) => i.date).reduce((a, b) => b.isAfter(a) ? b : a);

      return (
        key: key,
        user: user,
        name: name,
        phone: phone,
        invoices: invoices,
        totalAmount: totalAmount,
        purchaseCount: purchaseCount,
        returnCount: returnCount,
        latestDate: latestDate,
      );
    }).toList();

    // Check if selected user is valid
    final selectedUserData = _selectedRecentlyGeneratedUserKey != null
        ? userList.where((u) => u.key == _selectedRecentlyGeneratedUserKey).firstOrNull
        : null;

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
              // Drill-down View: If a user is selected, show their bills!
              if (selectedUserData != null) ...[
                _buildUserBillsDrillDown(selectedUserData),
              ] else ...[
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by User, Phone, Invoice No, Product...',
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
                      '${userList.length} ${userList.length == 1 ? 'User' : 'Users'} (${filtered.length} Bills)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List of Users or Empty state
                if (userList.isEmpty)
                  _buildEmptyInvoicesState()
                else
                  ...userList.map((u) => _buildUserCard(u)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBillsDrillDown(({
    String key,
    UserModel? user,
    String name,
    String phone,
    List<CustomInvoiceModel> invoices,
    double totalAmount,
    int purchaseCount,
    int returnCount,
    DateTime latestDate,
  }) item) {
    final isRegistered = item.user != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Button
        InkWell(
          onTap: () => setState(() => _selectedRecentlyGeneratedUserKey = null),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Text(
                  'Back to All Users',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // User Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.adminBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isRegistered
                        ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                        : const Color(0xFFF97316).withValues(alpha: 0.15),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isRegistered ? const Color(0xFF0284C7) : const Color(0xFFF97316),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSlate,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isRegistered) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'REGISTERED PAINTER',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSlateLight),
                              const SizedBox(width: 6),
                              Text(
                                item.phone,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSlateLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.adminBorder),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUserStat('Total Bills', '${item.invoices.length}'),
                  Container(width: 1, height: 28, color: AppColors.adminBorder),
                  _buildUserStat('Purchases', '${item.purchaseCount}'),
                  Container(width: 1, height: 28, color: AppColors.adminBorder),
                  _buildUserStat('Returns', '${item.returnCount}'),
                  Container(width: 1, height: 28, color: AppColors.adminBorder),
                  _buildUserStat('Net Total', '₹ ${item.totalAmount.abs().toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Title
        Text(
          'GENERATED BILLS FOR ${item.name.toUpperCase()} (${item.invoices.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSlateLight,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // Invoices list for this user
        ...item.invoices.map((inv) => _buildInvoiceCard(inv)),
      ],
    );
  }

  Widget _buildUserStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textSlate,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSlateLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(({
    String key,
    UserModel? user,
    String name,
    String phone,
    List<CustomInvoiceModel> invoices,
    double totalAmount,
    int purchaseCount,
    int returnCount,
    DateTime latestDate,
  }) item) {
    final isRegistered = item.user != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedRecentlyGeneratedUserKey = item.key;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isRegistered
                      ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                      : const Color(0xFFF97316).withValues(alpha: 0.12),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isRegistered ? const Color(0xFF0284C7) : const Color(0xFFF97316),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name, phone, stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSlate,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRegistered) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PAINTER',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.phone.isNotEmpty) ...[
                            const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSlateLight),
                            const SizedBox(width: 4),
                            Text(
                              item.phone,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            '${item.invoices.length} ${item.invoices.length == 1 ? 'bill' : 'bills'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Total amount & chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹ ${item.totalAmount.abs().toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(item.latestDate),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSlateLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSlateLight,
                  size: 20,
                ),
              ],
            ),
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF0284C7);
      case 'preparing':
        return const Color(0xFFF59E0B);
      case 'dispatched':
        return const Color(0xFF8B5CF6);
      case 'delivered':
        return const Color(0xFF10B981);
      case 'returned':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSlateLight;
    }
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
          // Row 1: Badges, Order Status, Invoice No, Date
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
                  if (invoice.orderStatus != null && invoice.orderStatus!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(invoice.orderStatus!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _statusColor(invoice.orderStatus!).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        invoice.orderStatus!.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _statusColor(invoice.orderStatus!),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
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
                  '${invoice.items.length} ${invoice.items.length == 1 ? 'item' : 'items'}: ${invoice.items.map((i) => '${i.productName} (${i.bucketSize}${i.shade != null && i.shade!.isNotEmpty ? ' • ${i.shade}' : ''}) x${i.quantity}').join(', ')}',
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
          'Delete Bill?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber} for ${invoice.painterName}? Yes / No',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(customInvoiceServiceProvider).deleteInvoice(invoice.id);
      if (invoice.orderId != null && invoice.orderId!.isNotEmpty) {
        await ref.read(dataServiceProvider).deleteOrderCompletely(invoice.orderId!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted invoice ${invoice.invoiceNumber} and its order'),
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

// =============================================================================
// PAINTER SEARCH DIALOG
// =============================================================================
class _PainterSelectionResult {
  final bool isClear;
  final UserModel? painter;

  const _PainterSelectionResult.select(this.painter) : isClear = false;
  const _PainterSelectionResult.clear() : isClear = true, painter = null;
}

class _PainterSearchDialog extends StatefulWidget {
  final List<UserModel> painters;
  final String? selectedPainterId;

  const _PainterSearchDialog({
    required this.painters,
    this.selectedPainterId,
  });

  @override
  State<_PainterSearchDialog> createState() => _PainterSearchDialogState();
}

class _PainterSearchDialogState extends State<_PainterSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> get _filteredPainters {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.painters;
    return widget.painters.where((p) {
      final name = p.name.toLowerCase();
      final phone = p.phone.toLowerCase();
      final email = p.email.toLowerCase();
      final business = (p.businessName ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || email.contains(q) || business.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPainters;

    return Dialog(
      backgroundColor: AppColors.adminCardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Color(0xFFF97316), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Painters',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSlate,
                          ),
                        ),
                        Text(
                          '${widget.painters.length} registered painters available',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSlateLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.adminBorder),

            // Search input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone number, or business...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSlateLight, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),

            // Sub-bar with results count & manual option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'painter' : 'painters'} found',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSlateLight),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, const _PainterSelectionResult.clear()),
                    icon: const Icon(Icons.person_off_outlined, size: 15, color: Color(0xFF0284C7)),
                    label: Text(
                      'Manual / Clear',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Results List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_off_rounded, size: 44, color: AppColors.textSlateLight),
                            const SizedBox(height: 10),
                            Text(
                              'No painters found for "$_query"',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSlate),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can enter customer details manually instead.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context, const _PainterSelectionResult.clear()),
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Enter Details Manually'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSlate,
                                side: const BorderSide(color: AppColors.adminBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isSelected = p.id == widget.selectedPainterId;

                        return InkWell(
                          onTap: () => Navigator.pop(context, _PainterSelectionResult.select(p)),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF97316).withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: p.isGold
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFE2E8F0),
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: p.isGold ? const Color(0xFFD97706) : AppColors.textSlate,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name, phone, business
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSlate,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (p.isGold) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFF59E0B)),
                                              ),
                                              child: Text(
                                                'GOLD',
                                                style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSlateLight),
                                          const SizedBox(width: 4),
                                          Text(
                                            p.phone,
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                                          ),
                                          if (p.businessName != null && p.businessName!.trim().isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textSlateLight)),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                p.businessName!,
                                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Points & Selection check
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (p.points > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '★ ${p.points} pts',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(Icons.check_circle_rounded, color: Color(0xFFF97316), size: 18),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PRODUCT SEARCH DIALOG
// =============================================================================
class _ProductSelectionResult {
  final bool isClear;
  final ProductModel? product;

  const _ProductSelectionResult.select(this.product) : isClear = false;
  const _ProductSelectionResult.clear() : isClear = true, product = null;
}

class _ProductSearchDialog extends StatefulWidget {
  final List<ProductModel> products;
  final String? selectedProductId;

  const _ProductSearchDialog({
    required this.products,
    this.selectedProductId,
  });

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedBrand = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _brands {
    final set = <String>{'All'};
    for (final p in widget.products) {
      if (p.brand.trim().isNotEmpty) set.add(p.brand.trim());
    }
    return set.toList();
  }

  List<ProductModel> get _filteredProducts {
    final q = _query.trim().toLowerCase();
    return widget.products.where((p) {
      if (_selectedBrand != 'All' && p.brand != _selectedBrand) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = p.name.toLowerCase();
      final code = p.colorCode.toLowerCase();
      final colorName = p.colorName.toLowerCase();
      final cat = p.category.toLowerCase();
      final sub = p.subCategory.toLowerCase();
      final brand = p.brand.toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          colorName.contains(q) ||
          cat.contains(q) ||
          sub.contains(q) ||
          brand.contains(q);
    }).toList();
  }

  Color? _parseColor(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    if (cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final brands = _brands;

    return Dialog(
      backgroundColor: AppColors.adminCardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.format_paint_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Catalog Products',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSlate,
                          ),
                        ),
                        Text(
                          '${widget.products.length} products available across brands',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSlateLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSlateLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.adminBorder),

            // Brand Filter Chips
            if (brands.length > 1)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: brands.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final brand = brands[i];
                    final isSelected = _selectedBrand == brand;
                    final brandColor = brand == 'All'
                        ? const Color(0xFF0284C7)
                        : AppColors.getBrandPrimary(brand);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedBrand = brand),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? brandColor.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? brandColor : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          brand,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? brandColor : AppColors.textSlate,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Search input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by product name, shade, code, category...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlateLight),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSlateLight, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.adminBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),

            // Counter & Custom Product Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'product' : 'products'} found',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSlateLight),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, const _ProductSelectionResult.clear()),
                    icon: const Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF0284C7)),
                    label: Text(
                      'Custom / Other Product',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Results List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 44, color: AppColors.textSlateLight),
                            const SizedBox(height: 10),
                            Text(
                              'No products found matching "$_query"',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSlate),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can enter this product manually on the invoice.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context, const _ProductSelectionResult.clear()),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                              label: const Text('Use Custom Product'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSlate,
                                side: const BorderSide(color: AppColors.adminBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isSelected = p.id == widget.selectedProductId;
                        final swatchColor = _parseColor(p.colorHex);
                        final brandColor = AppColors.getBrandPrimary(p.brand);

                        // Calculate starting price
                        double? minPrice;
                        if (p.prices.isNotEmpty) {
                          minPrice = p.prices.values.reduce((a, b) => a < b ? a : b);
                        }

                        return InkWell(
                          onTap: () => Navigator.pop(context, _ProductSelectionResult.select(p)),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Thumbnail / Swatch
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: swatchColor ?? brandColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: swatchColor != null
                                          ? Colors.black.withValues(alpha: 0.15)
                                          : brandColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: swatchColor == null
                                      ? Icon(Icons.format_paint_outlined, color: brandColor, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Name & brand & sizes
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSlate,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (p.colorCode.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.adminBorder),
                                              ),
                                              child: Text(
                                                p.colorCode,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSlate,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          // Brand badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: brandColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.brand,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: brandColor,
                                              ),
                                            ),
                                          ),
                                          if (p.category.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '•  ${p.category}',
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlateLight),
                                            ),
                                          ],
                                          if (p.bucketSizes.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '(${p.bucketSizes.join(', ')})',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlateLight),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Price & Selection check
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (minPrice != null && minPrice > 0)
                                      Text(
                                        '₹${minPrice.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSlate,
                                        ),
                                      ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 18),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
