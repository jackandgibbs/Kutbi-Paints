import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/qr_code_model.dart';
import '../../services/data_service.dart';
import 'qr_sticker_palette.dart';

class DeletedQRsScreen extends ConsumerStatefulWidget {
  const DeletedQRsScreen({super.key});

  @override
  ConsumerState<DeletedQRsScreen> createState() => _DeletedQRsScreenState();
}

class _DeletedQRsScreenState extends ConsumerState<DeletedQRsScreen> {
  final _dateFormat = DateFormat('MMM d, yyyy hh:mm a');
  String _searchQuery = '';
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  List<_DeletedBatchSummary> _buildDeletedSummaries(List<QRCodeModel> deletedQrs) {
    final grouped = <String, List<QRCodeModel>>{};
    for (final qr in deletedQrs) {
      grouped.putIfAbsent(qr.batchId, () => []).add(qr);
    }

    final summaries = grouped.entries.map((entry) {
      final codes = List<QRCodeModel>.from(entry.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _DeletedBatchSummary(codes);
    }).toList();

    final filtered = summaries.where((summary) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          summary.batchId.toLowerCase().contains(query) ||
          summary.representative.id.toLowerCase().contains(query) ||
          _dateFormat.format(summary.createdAt).toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> _confirmReactivate(_DeletedBatchSummary summary) async {
    final shouldReactivate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reactivate QR Batch?'),
            content: Text(
              'Reactivate ${summary.quantity} QR sticker(s) from batch ${summary.batchId}? '
              'Active stickers will be restored and scannable again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Reactivate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReactivate) return;

    try {
      await ref.read(dataServiceProvider).reactivateQRCodeBatch(summary.batchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR batch reactivated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reactivation failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    if (!ds.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('Deleted QR Stickers',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final deletedQrs = ds.getDeletedQRCodes();
    final summaries = _buildDeletedSummaries(deletedQrs);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 700;

    final totalItems = summaries.length;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
    final pagedSummaries = totalItems > 0
        ? summaries.sublist(startIndex, endIndex)
        : <_DeletedBatchSummary>[];

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
              'Deleted QR Stickers',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
              ),
            ),
            Text(
              '${deletedQrs.length} stickers in ${summaries.length} batches',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: AppColors.error, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deleted Batches',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 22 : 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Reactivate previously deleted QR sticker batches.',
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
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search deleted QR...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() {
                    _searchQuery = value;
                    _currentPage = 0;
                  }),
                ),
                const SizedBox(height: 16),
                if (summaries.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 64,
                              color: AppColors.success.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No deleted QR batches',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Deleted batches will appear here for recovery.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Pts'), numeric: true),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Qty'), numeric: true),
                            DataColumn(label: Text('Color')),
                            DataColumn(label: Text('Scans')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: pagedSummaries.map((summary) {
                            return DataRow(cells: [
                              DataCell(Text(summary.representative.id,
                                  style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.w700))),
                              DataCell(Text(
                                  '${summary.representative.points} pts')),
                              DataCell(Text(
                                  _dateFormat.format(summary.createdAt))),
                              DataCell(Text(summary.quantity.toString())),
                              DataCell(Row(children: [
                                Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                        color: summary.palette.primary,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(summary.palette.name),
                              ])),
                              DataCell(Text(
                                  '${summary.redeemedCount} / ${summary.quantity}')),
                              DataCell(
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _confirmReactivate(summary),
                                  icon: const Icon(Icons.restore_rounded,
                                      size: 16),
                                  label: const Text('Reactivate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    textStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pagination controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                            iconSize: 22,
                            splashRadius: 20,
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(
                                      () => _currentPage = pageIndex),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF2563EB)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${pageIndex + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isActive
                                            ? Colors.white
                                            : AppColors.textSecondary,
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletedBatchSummary {
  final List<QRCodeModel> codes;

  _DeletedBatchSummary(this.codes);

  QRCodeModel get representative => codes.first;
  String get batchId => representative.batchId;
  DateTime get createdAt => representative.createdAt;
  int get quantity =>
      representative.quantity > 0 ? representative.quantity : codes.length;
  int get redeemedCount =>
      codes.where((code) => code.usedBy != null).length;
  QRStickerPalette get palette =>
      qrStickerPaletteMap[representative.colorScheme] ??
      qrStickerPalettes.first;

  Uint8List? get logoBytes {
    final base64 = representative.customLogoBase64;
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }
}
