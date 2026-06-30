import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/constants/app_colors.dart';
import '../../models/qr_code_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/qr_sticker_export_service.dart';
import 'package:go_router/go_router.dart';
import 'qr_sticker_palette.dart';

class AdminQRGeneratorScreen extends ConsumerStatefulWidget {
  const AdminQRGeneratorScreen({super.key});

  @override
  ConsumerState<AdminQRGeneratorScreen> createState() =>
      _AdminQRGeneratorScreenState();
}

class _AdminQRGeneratorScreenState
    extends ConsumerState<AdminQRGeneratorScreen> {
  static const _defaultMessage = 'Scan with Kutbi Paints app';
  static const _quantitySuggestions = [5, 10, 25, 50, 100];

  final _formKey = GlobalKey<FormState>();
  final _previewBoundaryKey = GlobalKey();
  final _previewSectionKey = GlobalKey();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _quantityController = TextEditingController(text: '10');
  final _messageController = TextEditingController(text: _defaultMessage);
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('MMM d, yyyy hh:mm a');

  int _points = 50;
  String _selectedPaletteKey = 'teal';
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _previewId = '';
  Uint8List? _customLogoBytes;
  String? _customLogoName;
  bool _isGenerating = false;
  bool _isDownloadingPng = false;
  bool _isDownloadingPdf = false;
  bool _isExportingCsv = false;
  bool _formDirtySinceLastGeneration = true;
  Timer? _debounceTimer;
  List<QRCodeModel> _lastGeneratedBatch = const <QRCodeModel>[];
  int _sortColumnIndex = 3;
  bool _sortAscending = false;
  _BatchSortField _sortField = _BatchSortField.createdAt;
  int _pdfColumns = 2;
  int _pdfRows = 3;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _previewId = _buildUniqueId();
    _quantityController.addListener(_handleDraftChange);
    _messageController.addListener(_handleDraftChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _quantityController.removeListener(_handleDraftChange);
    _messageController.removeListener(_handleDraftChange);
    _quantityController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDraftChange() {
    if (!mounted) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _formDirtySinceLastGeneration = true;
          _previewId = _buildUniqueId(); // Refresh preview ID only on debounce
        });
      }
    });
  }

  QRStickerPalette get _selectedPalette =>
      qrStickerPaletteMap[_selectedPaletteKey] ?? qrStickerPalettes.first;

  int get _currentQuantity {
    final parsed = int.tryParse(_quantityController.text.trim()) ?? 10;
    return parsed.clamp(1, 100).toInt();
  }

  String get _effectiveMessage {
    final text = _messageController.text.trim();
    return text.isEmpty ? _defaultMessage : text;
  }

  QRCodeModel get _draftPreviewQr {
    return QRCodeModel(
      id: _previewId,
      batchId: 'draft',
      qrValue: _buildQrValue(_previewId, _points, isDraft: true),
      points: _points,
      colorScheme: _selectedPaletteKey,
      status: 'active',
      createdAt: DateTime.now(),
      quantity: _currentQuantity,
      message: _effectiveMessage,
      customLogoBase64:
          _customLogoBytes == null ? null : base64Encode(_customLogoBytes!),
      scans: 0,
    );
  }

  String _buildUniqueId([Set<String>? existingIds]) {
    final reserved = existingIds ?? <String>{};
    while (true) {
      // Increased to 8 characters for 100% uniqueness guarantee
      final candidate =
          'QR${_uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase()}';
      if (!reserved.contains(candidate)) {
        return candidate;
      }
    }
  }

  String _buildQrValue(String id, int points, {bool isDraft = false}) {
    return Uri(
      scheme: 'app',
      host: 'kutbi',
      path: 'redeem/$id',
      queryParameters: {
        'points': points.toString(),
        if (!isDraft) 'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    ).toString();
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an image smaller than 5MB.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _customLogoBytes = bytes;
      _customLogoName = picked.name;
      _formDirtySinceLastGeneration = true;
    });
  }

  Future<void> _generateBatch() async {
    if (!_formKey.currentState!.validate()) return;

    final ds = ref.read(dataServiceProvider);
    final user = ref.read(authProvider).user;
    final quantity = _currentQuantity;
    final now = DateTime.now();
    final batchId = 'BATCH_${now.millisecondsSinceEpoch}';
    final allIds = ds.getAllQRCodes().map((q) => q.id).toSet();
    // Only store logo in first QR of batch to save memory
    final logoBase64 = _customLogoBytes == null ? null : base64Encode(_customLogoBytes!);

    setState(() {
      _isGenerating = true;
    });

    try {
      final qrs = <QRCodeModel>[];
      
      for (int i = 0; i < quantity; i++) {
        final id = _buildUniqueId(allIds);
        allIds.add(id);
        qrs.add(
          QRCodeModel(
            id: id,
            batchId: batchId,
            qrValue: _buildQrValue(id, _points),
            points: _points,
            colorScheme: _selectedPaletteKey,
            status: 'active',
            createdAt: now,
            quantity: quantity,
            message: _effectiveMessage,
            createdBy: user?.id,
            customLogoBase64: i == 0 ? logoBase64 : null,
            scans: 0,
          ),
        );
        
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      for (int i = 0; i < qrs.length; i += 20) {
        final end = (i + 20 < qrs.length) ? i + 20 : qrs.length;
        await ds.addQRCodes(qrs.sublist(i, end));
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      if (!mounted) return;

      setState(() {
        _lastGeneratedBatch = qrs;
        _formDirtySinceLastGeneration = false;
        _previewId = _buildUniqueId(allIds);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${qrs.length} QR sticker(s) successfully.'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );

      final previewContext = _previewSectionKey.currentContext;
      if (previewContext != null) {
        await Scrollable.ensureVisible(
          previewContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate QR stickers: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _points = 50;
      _selectedPaletteKey = 'teal';
      _quantityController.text = '10';
      _messageController.text = _defaultMessage;
      _customLogoBytes = null;
      _customLogoName = null;
      _previewId = _buildUniqueId(
        ref.read(dataServiceProvider).getAllQRCodes().map((q) => q.id).toSet(),
      );
      _formDirtySinceLastGeneration = true;
    });
  }

  Future<Uint8List> _capturePreviewPng() async {
    final context = _previewBoundaryKey.currentContext;
    if (context == null) {
      throw Exception('Preview is not ready yet.');
    }

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Preview render boundary is unavailable.');
    }

    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    final image = await boundary.toImage(pixelRatio: 4);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Unable to capture PNG preview.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _shareBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String text,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: mimeType,
            name: filename,
          ),
        ],
        text: text,
        subject: filename,
      );
    } catch (e) {
      debugPrint('Error sharing bytes: $e');
      rethrow;
    }
  }

  Future<void> _downloadPreviewPng() async {
    setState(() => _isDownloadingPng = true);
    try {
      final pngBytes = await _capturePreviewPng();
      final filename =
          'qr_sticker_${_draftPreviewQr.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      await _shareBytes(
        bytes: pngBytes,
        filename: filename,
        mimeType: 'image/png',
        text: 'Kutbi Paints QR sticker preview',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNG sticker exported successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PNG export failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPng = false);
      }
    }
  }

  Future<void> _downloadBatchPdf(List<QRCodeModel> batch) async {
    if (batch.isEmpty) return;
    
    // Show immediate feedback for large batches
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Generating PDF for ${batch.length} stickers ($_pdfColumns×$_pdfRows per page)...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() => _isDownloadingPdf = true);
    try {
      final pdfBytes = await QRStickerExportService.buildBatchPdf(
        qrs: batch,
        columns: _pdfColumns,
        rows: _pdfRows,
      );
      
      // On Windows/Web/Desktop, Printing.layoutPdf is much more reliable for PDFs
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'qr_stickers_batch_${batch.length}',
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF sticker pack opened successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  Future<void> _downloadCurrentBatchPdf() async {
    if (_lastGeneratedBatch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Click "Generate QR Code" first to create the batch.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    if (_formDirtySinceLastGeneration) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download Last Batch?'),
          content: const Text('You have unsaved changes in the form. Do you want to download the last successfully generated batch instead?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download Last Batch')),
          ],
        ),
      ) ?? false;
      
      if (!shouldContinue) return;
    }

    await _downloadBatchPdf(_lastGeneratedBatch);
  }

  Future<void> _downloadAllActivePdf() async {
    final activeQrs = ref.read(dataServiceProvider).getAllQRCodes().where((q) => q.status == 'active').toList();
    if (activeQrs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active QR codes found to download.')),
      );
      return;
    }
    await _downloadBatchPdf(activeQrs);
  }

  Future<void> _exportHistoryCsv(List<_QRCodeBatchSummary> summaries) async {
    setState(() => _isExportingCsv = true);
    try {
      final rows = <List<dynamic>>[
        [
          'QR ID',
          'Batch ID',
          'Points',
          'Status',
          'Created At',
          'Quantity',
          'Color Scheme',
          'Scans',
        ],
      ];

      for (final summary in summaries) {
        rows.add([
          summary.representative.id,
          summary.batchId,
          summary.representative.points,
          summary.status,
          _dateFormat.format(summary.createdAt),
          summary.quantity,
          summary.palette.name,
          '${summary.redeemedCount}/${summary.quantity}',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      await _shareBytes(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        filename:
            'qr_history_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
        mimeType: 'text/csv',
        text: 'Kutbi Paints QR history export',
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingCsv = false);
      }
    }
  }

  void _duplicateBatch(_QRCodeBatchSummary summary) {
    setState(() {
      _points = summary.representative.points;
      _selectedPaletteKey = summary.representative.colorScheme;
      _quantityController.text = summary.quantity.toString();
      _messageController.text = summary.representative.message ?? _defaultMessage;
      _customLogoBytes = summary.logoBytes;
      _customLogoName = summary.logoBytes == null ? null : 'duplicated-logo.png';
      _previewId = _buildUniqueId(
        ref.read(dataServiceProvider).getAllQRCodes().map((q) => q.id).toSet(),
      );
      _formDirtySinceLastGeneration = true;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showEditDialog(_QRCodeBatchSummary summary) async {
    int points = summary.representative.points;
    String message = summary.representative.message ?? _defaultMessage;
    String paletteKey = summary.representative.colorScheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final palette =
                qrStickerPaletteMap[paletteKey] ?? qrStickerPalettes.first;
            return AlertDialog(
              title: Text(
                'Edit Batch ${summary.batchId}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reward Points: $points',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: points.toDouble(),
                      min: 10,
                      max: 1000,
                      divisions: 198,
                      activeColor: palette.primary,
                      onChanged: (value) {
                        setModalState(() => points = (value / 5).round() * 5);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: message,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => message = value,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paletteKey,
                      decoration: const InputDecoration(
                        labelText: 'Color Theme',
                        border: OutlineInputBorder(),
                      ),
                      items: qrStickerPalettes
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => paletteKey = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(dataServiceProvider).updateQRCodeBatch(
                            batchId: summary.batchId,
                            points: points,
                            message: message.trim().isEmpty
                                ? _defaultMessage
                                : message.trim(),
                            colorScheme: paletteKey,
                            customLogoBase64:
                                summary.logoBytes == null ? null : base64Encode(summary.logoBytes!),
                          );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR batch updated successfully.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Update failed: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteBatch(_QRCodeBatchSummary summary) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete QR Batch?'),
            content: Text(
              'Delete ${summary.quantity} QR sticker(s) from batch ${summary.batchId}? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await ref.read(dataServiceProvider).deleteQRCodeBatch(summary.batchId);
      if (_lastGeneratedBatch.isNotEmpty &&
          _lastGeneratedBatch.first.batchId == summary.batchId) {
        setState(() {
          _lastGeneratedBatch = const <QRCodeModel>[];
          _formDirtySinceLastGeneration = true;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR batch deleted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showBatchDetails(_QRCodeBatchSummary summary) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final timeline = summary.codes
            .where((code) => code.usedAt != null)
            .toList()
          ..sort((a, b) => b.usedAt!.compareTo(a.usedAt!));
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QR Batch Details',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StickerPreviewCard(
                            qr: summary.representative,
                            palette: summary.palette,
                            logoBytes: summary.logoBytes,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow('QR ID', summary.representative.id),
                                _detailRow('Batch ID', summary.batchId),
                                _detailRow(
                                  'Created',
                                  _dateFormat.format(summary.createdAt),
                                ),
                                _detailRow(
                                  'Quantity',
                                  '${summary.quantity} stickers',
                                ),
                                _detailRow(
                                  'Reward Value',
                                  '${summary.representative.points} points',
                                ),
                                _detailRow('Theme', summary.palette.name),
                                _detailRow(
                                  'Scans',
                                  '${summary.redeemedCount} / ${summary.quantity}',
                                ),
                                _detailRow('Status', summary.statusLabel),
                                const SizedBox(height: 20),
                                Text(
                                  'Scan Timeline',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (timeline.isEmpty)
                                  Text(
                                    'No scans recorded yet.',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else
                                  ...timeline.map((qr) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${qr.usedByName ?? qr.usedBy ?? 'Unknown user'} - ${_dateFormat.format(qr.usedAt!.toLocal())}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  List<_QRCodeBatchSummary> _buildSummaries(List<QRCodeModel> qrs) {
    final grouped = <String, List<QRCodeModel>>{};
    for (final qr in qrs) {
      grouped.putIfAbsent(qr.batchId, () => []).add(qr);
    }

    final summaries = grouped.entries.map((entry) {
      final codes = List<QRCodeModel>.from(entry.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _QRCodeBatchSummary(codes);
    }).toList();

    final filtered = summaries.where((summary) {
      // Exclude deleted batches from main history
      if (summary.status == 'deleted') return false;
      final matchesFilter =
          _statusFilter == 'all' || summary.status == _statusFilter;
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          summary.batchId.toLowerCase().contains(query) ||
          summary.representative.id.toLowerCase().contains(query) ||
          _dateFormat.format(summary.createdAt).toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case _BatchSortField.id:
          comparison = a.representative.id.compareTo(b.representative.id);
          break;
        case _BatchSortField.points:
          comparison =
              a.representative.points.compareTo(b.representative.points);
          break;
        case _BatchSortField.status:
          comparison = a.status.compareTo(b.status);
          break;
        case _BatchSortField.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case _BatchSortField.quantity:
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case _BatchSortField.color:
          comparison = a.palette.name.compareTo(b.palette.name);
          break;
        case _BatchSortField.scans:
          comparison = a.redeemedCount.compareTo(b.redeemedCount);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _sortBy(_BatchSortField field, int columnIndex, bool ascending) {
    setState(() {
      _sortField = field;
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    
    if (!ds.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('QR Generator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final qrs = ds.getAllQRCodes();
    final summaries = _buildSummaries(qrs);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 700;

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kutbi Paints QR Generator',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
              ),
            ),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMetrics(qrs, summaries, screenWidth),
            const SizedBox(height: 20),
            _buildFormPanel(isTablet),
            const SizedBox(height: 20),
            _buildPreviewPanel(isTablet),
            const SizedBox(height: 24),
            _buildHistorySection(summaries, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(
    List<QRCodeModel> qrs,
    List<_QRCodeBatchSummary> summaries,
    double screenWidth,
  ) {
    final ds = ref.read(dataServiceProvider);
    final activeCount = ds.activeQRCount;
    final usedCount = ds.usedQRCount;
    final totalPoints = ds.totalPointsIssued;
    
    final cardWidth = screenWidth > 1200 
        ? 220.0 
        : screenWidth > 800 
            ? (screenWidth - 80) / 3 
            : (screenWidth - 54) / 2;

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _MetricCard(
          label: 'Batches',
          value: summaries.length.toString(),
          icon: Icons.dashboard_customize_rounded,
          color: const Color(0xFF2563EB),
          width: cardWidth,
        ),
        _MetricCard(
          label: 'Stickers',
          value: qrs.length.toString(),
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF0F766E),
          width: cardWidth,
        ),
        _MetricCard(
          label: 'Points Issued',
          value: totalPoints.toString(),
          icon: Icons.stars_rounded,
          color: const Color(0xFFD97706),
          width: cardWidth,
        ),
        _MetricCard(
          label: 'Active QRs',
          value: activeCount.toString(),
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
          onTap: _downloadAllActivePdf,
          actionLabel: 'PDF',
          width: cardWidth,
        ),
        _MetricCard(
          label: 'Redeemed',
          value: usedCount.toString(),
          icon: Icons.verified_rounded,
          color: const Color(0xFF7C3AED),
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildFormPanel(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Generator',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Customize your stickers here.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Points Value: $_points',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _selectedPalette.primary,
                inactiveTrackColor: _selectedPalette.secondary,
                thumbColor: _selectedPalette.primary,
                overlayColor: _selectedPalette.primary.withValues(alpha: 0.14),
                trackHeight: 6,
              ),
              child: Slider(
                value: _points.toDouble(),
                min: 10,
                max: 1000,
                divisions: 198,
                onChanged: (value) {
                  setState(() {
                    _points = (value / 5).round() * 5;
                    _formDirtySinceLastGeneration = true;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Max 100',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.numbers),
                isDense: !isTablet,
              ),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < 1 || parsed > 100) {
                  return 'Enter 1-100';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quantitySuggestions.map((qty) {
                final isSelected = _quantityController.text.trim() == '$qty';
                return ChoiceChip(
                  label: Text('$qty'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _quantityController.text = qty.toString();
                      _formDirtySinceLastGeneration = true;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _messageController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'e.g. Scan for rewards',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                isDense: !isTablet,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Color Theme',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: qrStickerPalettes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isTablet ? 1 : 1.4,
              ),
              itemBuilder: (context, index) {
                final palette = qrStickerPalettes[index];
                final isSelected = palette.key == _selectedPaletteKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _selectedPaletteKey = palette.key;
                      _formDirtySinceLastGeneration = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? palette.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: isTablet ? 30 : 20,
                          height: isTablet ? 30 : 20,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            palette.name,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.upload_file),
              label: Text(_customLogoName != null ? 'Change Logo' : 'Upload Logo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PDF Layout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Columns: $_pdfColumns', style: GoogleFonts.poppins(fontSize: 12)),
                      Slider(
                        value: _pdfColumns.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) => setState(() => _pdfColumns = v.toInt()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rows: $_pdfRows', style: GoogleFonts.poppins(fontSize: 12)),
                      Slider(
                        value: _pdfRows.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) => setState(() => _pdfRows = v.toInt()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedPalette.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view_rounded, size: 18, color: _selectedPalette.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Total per page: ${_pdfColumns * _pdfRows}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _selectedPalette.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text('Generating...', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Text(
                        'Generate Batch',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: highlight ? 20 : 15,
            fontWeight: FontWeight.w700,
            color: highlight ? _selectedPalette.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel(bool isTablet) {
    final draftQr = _draftPreviewQr;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 22 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live Preview',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _formDirtySinceLastGeneration ? Icons.edit_note_rounded : Icons.verified_rounded,
                    color: _formDirtySinceLastGeneration ? Colors.orange : AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth < 360 ? screenWidth - 64 : 300,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      key: _previewBoundaryKey,
                      child: _StickerPreviewCard(
                        qr: draftQr,
                        palette: _selectedPalette,
                        logoBytes: _customLogoBytes,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isDownloadingPng ? null : _downloadPreviewPng,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('PNG'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDownloadingPdf ? null : _downloadCurrentBatchPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPalette.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          if (_formDirtySinceLastGeneration && _lastGeneratedBatch.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Note: Click "Generate" to save and print this batch.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
        ),
        // Blur overlay with progress bar when downloading PDF
        if (_isDownloadingPdf)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 10,
                            offset: const Offset(-5, -5),
                          ),
                          BoxShadow(
                            color: const Color(0xFFD1CCC4).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(5, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Generating PDF...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 180,
                            child: Column(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0DCD6),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        blurRadius: 2,
                                        offset: const Offset(-1, -1),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFFD1CCC4).withValues(alpha: 0.4),
                                        blurRadius: 2,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(seconds: 3),
                                    builder: (context, value, _) {
                                      return FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _selectedPalette.primary,
                                                _selectedPalette.accent,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please wait...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
              ),
            ),
          ),
      ],
    );
  }

  Widget _colorRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: ${_hex(color)}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 46,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  String _hex(Color color) {
    final hex = '${color.r.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.g.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.b.toInt().toRadixString(16).padLeft(2, '0')}';
    return '#${hex.toUpperCase()}';
  }

  Widget _buildHistorySection(List<_QRCodeBatchSummary> summaries, bool isTablet) {
    final totalItems = summaries.length;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    // Clamp current page
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
    final pagedSummaries = totalItems > 0 ? summaries.sublist(startIndex, endIndex) : <_QRCodeBatchSummary>[];

    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'History',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.push('/admin/deleted-qrs'),
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Deleted QRs',
                color: AppColors.error,
              ),
              IconButton(
                onPressed: _isExportingCsv ? null : () => _exportHistoryCsv(summaries),
                icon: const Icon(Icons.file_download_rounded),
                tooltip: 'Export CSV',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search QR...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (value) => setState(() {
              _searchQuery = value;
              _currentPage = 0;
            }),
          ),
          const SizedBox(height: 16),
          if (summaries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No QR batches yet. Generate your first batch above!',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...
            [
              SizedBox(
                height: 400,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Pts'), numeric: true),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Color')),
                        DataColumn(label: Text('Scans')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: pagedSummaries.map((summary) {
                        return DataRow(cells: [
                          DataCell(Text(summary.representative.id, style: GoogleFonts.robotoMono(fontWeight: FontWeight.w700))),
                          DataCell(Text('${summary.representative.points} pts')),
                          DataCell(_statusChip(summary.status)),
                          DataCell(Text(_dateFormat.format(summary.createdAt))),
                          DataCell(Text(summary.quantity.toString())),
                          DataCell(Row(children: [
                            Container(width: 14, height: 14, decoration: BoxDecoration(color: summary.palette.primary, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(summary.palette.name),
                          ])),
                          DataCell(Text('${summary.redeemedCount} / ${summary.quantity}')),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _downloadBatchPdf(summary.codes),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteBatch(summary),
                            ),
                          ])),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pagination controls
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        iconSize: 22,
                        splashRadius: 20,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      ...List.generate(
                        totalPages > 5 ? 5 : totalPages,
                        (i) {
                          int pageIndex;
                          if (totalPages <= 5) {
                            pageIndex = i;
                          } else if (_currentPage < 3) {
                            pageIndex = i;
                          } else if (_currentPage > totalPages - 4) {
                            pageIndex = totalPages - 5 + i;
                          } else {
                            pageIndex = _currentPage - 2 + i;
                          }
                          final isActive = pageIndex == _currentPage;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _currentPage = pageIndex),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${pageIndex + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        iconSize: 22,
                        splashRadius: 20,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    late final Color color;
    late final String label;
    switch (status) {
      case 'active':
        color = AppColors.success;
        label = 'Active';
        break;
      case 'used':
        color = const Color(0xFF2563EB);
        label = 'Used';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StickerPreviewCard extends StatelessWidget {
  final QRCodeModel qr;
  final QRStickerPalette palette;
  final Uint8List? logoBytes;

  const _StickerPreviewCard({
    required this.qr,
    required this.palette,
    this.logoBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300, // Fixed size to match PDF aspect ratio better
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.secondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (logoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    logoBytes!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              const SizedBox(width: 10),
              Text(
                'Kutbi Paints',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ],
          ),

          // QR Code
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qr.qrValue,
              version: QrVersions.auto,
              size: 130, // Reduced size for better layout
              backgroundColor: Colors.white,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: palette.text,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),

          // Info
          Column(
            children: [
              Text(
                qr.message ?? 'Scan with Kutbi Paints app',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${qr.id.toUpperCase()}',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Reward: ${qr.points} Points',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? actionLabel;
  final double width;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                if (actionLabel != null) ...[
                  const Spacer(),
                  Text(
                    actionLabel!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QRCodeBatchSummary {
  final List<QRCodeModel> codes;

  _QRCodeBatchSummary(this.codes);

  QRCodeModel get representative => codes.first;
  String get batchId => representative.batchId;
  DateTime get createdAt => representative.createdAt;
  int get quantity => representative.quantity > 0 ? representative.quantity : codes.length;
  int get redeemedCount => codes.where((code) => code.status == 'used').length;
  QRStickerPalette get palette =>
      qrStickerPaletteMap[representative.colorScheme] ?? qrStickerPalettes.first;

  Uint8List? get logoBytes {
    final base64 = representative.customLogoBase64;
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  String get status {
    if (codes.any((code) => code.status == 'active')) return 'active';
    if (codes.every((code) => code.status == 'used')) return 'used';
    if (codes.any((code) => code.status == 'expired')) return 'expired';
    if (codes.any((code) => code.status == 'archived')) return 'archived';
    return representative.status;
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'used':
        return 'Used';
      case 'expired':
        return 'Expired';
      case 'archived':
        return 'Archived';
      default:
        return 'Unknown';
    }
  }
}

class _QRCodeBatchTableSource extends DataTableSource {
  final List<_QRCodeBatchSummary> summaries;
  final DateFormat dateFormat;
  final void Function(_QRCodeBatchSummary summary) onView;
  final Future<void> Function(_QRCodeBatchSummary summary) onEdit;
  final Future<void> Function(_QRCodeBatchSummary summary) onDelete;
  final void Function(_QRCodeBatchSummary summary) onDuplicate;
  final Future<void> Function(_QRCodeBatchSummary summary) onDownload;

  _QRCodeBatchTableSource({
    required this.summaries,
    required this.dateFormat,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDownload,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= summaries.length) return null;
    final summary = summaries[index];
    final color = summary.palette.primary;
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(
          Text(
            summary.representative.id,
            style: GoogleFonts.robotoMono(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text('${summary.representative.points} pts')),
        DataCell(_statusChip(summary.status)),
        DataCell(Text(dateFormat.format(summary.createdAt))),
        DataCell(Text(summary.quantity.toString())),
        DataCell(
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(summary.palette.name),
            ],
          ),
        ),
        DataCell(Text('${summary.redeemedCount} / ${summary.quantity}')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onDownload(summary),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (value) {
                  switch (value) {
                    case 'download': onDownload(summary); break;
                    case 'edit': onEdit(summary); break;
                    case 'delete': onDelete(summary); break;
                    case 'view': onView(summary); break;
                    case 'duplicate': onDuplicate(summary); break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'download', child: Text('Download PDF')),
                  PopupMenuItem(value: 'edit', enabled: summary.status == 'active', child: const Text('Edit Batch')),
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Batch')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete Batch')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    late final Color color;
    late final String label;
    switch (status) {
      case 'active':
        color = AppColors.success;
        label = 'Active';
        break;
      case 'used':
        color = const Color(0xFF2563EB);
        label = 'Used';
        break;
      case 'expired':
        color = AppColors.warning;
        label = 'Expired';
        break;
      default:
        color = Colors.grey;
        label = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => summaries.length;

  @override
  int get selectedRowCount => 0;
}

enum _BatchSortField {
  id,
  points,
  status,
  createdAt,
  quantity,
  color,
  scans,
}
