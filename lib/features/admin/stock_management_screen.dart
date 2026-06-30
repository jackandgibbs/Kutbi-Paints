import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/data_service.dart';

const _kRowId = 'main';

const List<Map<String, String>> _defaultBases = [
  {'name': 'White', 'label': 'Direct White'},
  {'name': 'Pe 1', 'label': 'Pastel'},
  {'name': 'Pe 2', 'label': 'Mid Tone'},
  {'name': 'Pe 5', 'label': 'Organic Yellow'},
  {'name': 'Pe 6', 'label': 'Organic Red'},
  {'name': 'Pe 99', 'label': 'Clear'},
];

Map<String, _BaseEntry> _makeDefaultBases() =>
    {for (var b in _defaultBases) '${b['name']} (${b['label']})': _BaseEntry(qty: 0, threshold: 5)};

class StockManagementScreen extends ConsumerStatefulWidget {
  const StockManagementScreen({super.key});
  @override
  ConsumerState<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends ConsumerState<StockManagementScreen> {
  String _search = '';
  String _statusFilter = 'All';
  final _searchCtrl = TextEditingController();
  // productId -> bases map (loaded from Supabase)
  Map<String, Map<String, _BaseEntry>> _stockData = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sb = Supabase.instance.client;
      final resp = await sb.from('admin_stock').select().eq('id', _kRowId).maybeSingle();
      if (resp != null && resp['data'] != null) {
        final map = resp['data'] as Map<String, dynamic>;
        _stockData = map.map((productId, bases) {
          final basesMap = (bases as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, _BaseEntry.fromJson(v as Map<String, dynamic>)),
          );
          return MapEntry(productId, basesMap);
        });
      }
    } catch (e) {
      debugPrint('Error loading stock from Supabase: $e');
    }
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final sb = Supabase.instance.client;
      final jsonData = _stockData.map((pid, bases) =>
          MapEntry(pid, bases.map((k, v) => MapEntry(k, v.toJson()))));
      await sb.from('admin_stock').upsert({
        'id': _kRowId,
        'data': jsonData,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving stock to Supabase: $e');
    }
  }

  Future<void> _exportPDF(List products) async {
    final pdf = pw.Document();
    final rows = <List<String>>[];
    for (final p in products) {
      final bases = _basesFor(p.id);
      for (final e in bases.entries) {
        rows.add([p.name, e.key, e.value.qty.toString(), e.value.status.replaceAll('_', ' ')]);
      }
    }
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Stock Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Base', 'Qty', 'Status'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Map<String, _BaseEntry> _basesFor(String productId) {
    if (!_stockData.containsKey(productId)) {
      _stockData[productId] = _makeDefaultBases();
    }
    return _stockData[productId]!;
  }

  String _worstStatus(Map<String, _BaseEntry> bases) {
    if (bases.values.any((b) => b.status == 'out_of_stock')) return 'out_of_stock';
    if (bases.values.any((b) => b.status == 'low_stock')) return 'low_stock';
    return 'in_stock';
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    var products = ds.getAllProducts();

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      products = products.where((p) => p.name.toLowerCase().contains(q) || p.colorCode.toLowerCase().contains(q)).toList();
    }
    // Status filter
    if (_statusFilter != 'All') {
      products = products.where((p) {
        final bases = _basesFor(p.id);
        final worst = _worstStatus(bases);
        if (_statusFilter == 'In Stock') return worst == 'in_stock';
        if (_statusFilter == 'Low Stock') return worst == 'low_stock';
        if (_statusFilter == 'Out of Stock') return worst == 'out_of_stock';
        return true;
      }).toList();
    }

    // Stats
    final allProducts = ds.getAllProducts();
    int totalBases = 0, lowCount = 0, outCount = 0;
    for (final p in allProducts) {
      final bases = _basesFor(p.id);
      totalBases += bases.length;
      final w = _worstStatus(bases);
      if (w == 'low_stock') lowCount++;
      if (w == 'out_of_stock') outCount++;
    }

    if (!_loaded || !ds.isLoaded) {
      return const Scaffold(backgroundColor: Color(0xFFF0EDE8), body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textSlate)),
        title: Text('Stock Management', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textSlate, fontSize: 20)),
        actions: [
          IconButton(
            onPressed: () => _exportPDF(allProducts),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
            tooltip: 'Export PDF',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/add-product'),
        backgroundColor: AppColors.adminPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Personal inventory — not linked to painter accounts', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlateLight, fontStyle: FontStyle.italic)),
              ),
              // Stats
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  _stat('Total Products', '${allProducts.length}', Icons.inventory_2_rounded, const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  _stat('Total Bases', '$totalBases', Icons.palette_rounded, const Color(0xFF0EA5E9)),
                  const SizedBox(width: 8),
                  _stat('Low Stock', '$lowCount', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _stat('Out of Stock', '$outCount', Icons.block_rounded, AppColors.error),
                ]),
              ),
              // Search + Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(flex: 3, child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                    child: TextField(
                      controller: _searchCtrl, onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(hintText: 'Search products...', hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13), prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.adminPrimary), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.adminPrimary),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(child: DropdownButton<String>(
                          value: _statusFilter, isDense: true,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSlate, fontWeight: FontWeight.w600),
                          items: ['All', 'In Stock', 'Low Stock', 'Out of Stock'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                        )),
                      ],
                    ),
                  ),
                ]),
              ),
              // List
              Expanded(
                child: products.isEmpty
                  ? Center(child: Text('No products found', style: GoogleFonts.inter(color: AppColors.textSlateLight)))
                  : RefreshIndicator(
                      onRefresh: () async { await _load(); },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: products.length,
                        itemBuilder: (ctx, i) {
                          final p = products[i];
                          return _ProductCard(
                            productName: p.name,
                            productCode: p.colorCode.isNotEmpty ? p.colorCode : p.brand,
                            brand: p.brand,
                            imageUrl: p.imageUrl,
                            bases: _basesFor(p.id),
                            onBasesChanged: (newBases) {
                              setState(() => _stockData[p.id] = newBases);
                              _save();
                            },
                          );
                        },
                      ),
                    ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSlate)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSlateLight), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

// ─── Product Card ───────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final String productName, productCode, brand;
  final String? imageUrl;
  final Map<String, _BaseEntry> bases;
  final ValueChanged<Map<String, _BaseEntry>> onBasesChanged;
  const _ProductCard({required this.productName, required this.productCode, required this.brand, this.imageUrl, required this.bases, required this.onBasesChanged});
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _expanded = false;
  final _newBaseCtrl = TextEditingController();

  @override
  void dispose() { _newBaseCtrl.dispose(); super.dispose(); }

  Color _dotColor(String status) {
    if (status == 'out_of_stock') return AppColors.error;
    if (status == 'low_stock') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Widget _pill(String status) {
    final c = _dotColor(status);
    final l = status == 'out_of_stock' ? 'Out of Stock' : status == 'low_stock' ? 'Low Stock' : 'In Stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(l, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }

  String get _worstStatus {
    if (widget.bases.values.any((b) => b.status == 'out_of_stock')) return 'out_of_stock';
    if (widget.bases.values.any((b) => b.status == 'low_stock')) return 'low_stock';
    return 'in_stock';
  }

  void _editBase(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Rename Base', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
      content: TextField(controller: ctrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final n = ctrl.text.trim();
            if (n.isEmpty || n == oldName) { Navigator.pop(ctx); return; }
            final bases = Map<String, _BaseEntry>.from(widget.bases);
            final entry = bases.remove(oldName);
            if (entry != null) bases[n] = entry;
            widget.onBasesChanged(bases);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save'),
        ),
      ],
    ));
  }

  void _deleteBase(String name) {
    final bases = Map<String, _BaseEntry>.from(widget.bases);
    bases.remove(name);
    widget.onBasesChanged(bases);
  }

  void _addBase() {
    final name = _newBaseCtrl.text.trim();
    if (name.isEmpty) return;
    if (widget.bases.containsKey(name)) return;
    final bases = Map<String, _BaseEntry>.from(widget.bases);
    bases[name] = _BaseEntry(qty: 0, threshold: 5);
    widget.onBasesChanged(bases);
    _newBaseCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = widget.bases.values.fold(0, (s, b) => s + b.qty);
    final dotColor = _dotColor(_worstStatus);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFF0EDE8), borderRadius: BorderRadius.circular(12)),
                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(widget.imageUrl!, fit: BoxFit.cover))
                  : Icon(Icons.format_paint_rounded, color: AppColors.getBrandPrimary(widget.brand), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(widget.productName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSlate), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text('${widget.productCode} · ${widget.bases.length} bases · $totalUnits units', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlateLight)),
              ])),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSlateLight),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Table Header
              Row(children: [
                Expanded(flex: 3, child: Text('Base/Variant', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSlateLight))),
                Expanded(flex: 2, child: Text('Qty', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSlateLight), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Threshold', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSlateLight), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Status', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSlateLight), textAlign: TextAlign.center)),
                const SizedBox(width: 60),
              ]),
              const SizedBox(height: 8),
              ...widget.bases.entries.map((e) => _baseRow(e.key, e.value)),
              const SizedBox(height: 16),
              // Add base
              Row(children: [
                Expanded(child: TextField(
                  controller: _newBaseCtrl,
                  decoration: InputDecoration(hintText: 'New base name...', hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200))),
                  style: GoogleFonts.inter(fontSize: 13),
                  onSubmitted: (_) => _addBase(),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addBase,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.adminPrimary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _baseRow(String name, _BaseEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSlate), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: _numInput(entry.qty, (v) {
          final bases = Map<String, _BaseEntry>.from(widget.bases);
          bases[name] = entry.copyWith(qty: v);
          widget.onBasesChanged(bases);
        })),
        Expanded(flex: 2, child: _numInput(entry.threshold, (v) {
          final bases = Map<String, _BaseEntry>.from(widget.bases);
          bases[name] = entry.copyWith(threshold: v);
          widget.onBasesChanged(bases);
        })),
        Expanded(flex: 2, child: Center(child: _pill(entry.status))),
        SizedBox(width: 60, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(onTap: () => _editBase(name), child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.adminPrimary)),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _deleteBase(name), child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error)),
        ])),
      ]),
    );
  }

  Widget _numInput(int value, ValueChanged<int> onChanged) {
    return GestureDetector(
      onTap: () {
        final ctrl = TextEditingController(text: '$value');
        showDialog(context: context, builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Enter Value', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, inputFormatters: [FilteringTextInputFormatter.digitsOnly], textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700), decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () { onChanged(int.tryParse(ctrl.text) ?? 0); Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Apply')),
          ],
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.adminPrimary.withOpacity(0.2))),
        alignment: Alignment.center,
        child: Text('$value', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSlate)),
      ),
    );
  }
}

// ─── Data Model ─────────────────────────────────────────────────────────
class _BaseEntry {
  final int qty;
  final int threshold;
  _BaseEntry({required this.qty, required this.threshold});

  String get status {
    if (qty <= 0) return 'out_of_stock';
    if (qty <= threshold) return 'low_stock';
    return 'in_stock';
  }

  _BaseEntry copyWith({int? qty, int? threshold}) => _BaseEntry(qty: qty ?? this.qty, threshold: threshold ?? this.threshold);
  Map<String, dynamic> toJson() => {'qty': qty, 'threshold': threshold};
  factory _BaseEntry.fromJson(Map<String, dynamic> j) => _BaseEntry(qty: j['qty'] ?? 0, threshold: j['threshold'] ?? 5);
}
