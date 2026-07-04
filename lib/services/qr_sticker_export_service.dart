import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../features/admin/qr_sticker_palette.dart';
import '../models/qr_code_model.dart';

class QRStickerExportService {
  // 3 inches = 76.2 mm
  static const double stickerSizeMm = 76.2;

  static Future<Uint8List> loadDefaultLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      // Return empty list or handle as needed
      return Uint8List(0);
    }
  }

  static Future<Uint8List> buildBatchPdf({
    required List<QRCodeModel> qrs,
    int columns = 2,
    int rows = 3,
  }) async {
    final stickersPerPage = columns * rows;
    final pdf = pw.Document(
      title: 'Kutbi Paints - QR Sticker Batch',
      author: 'Kutbi Admin',
      compress: true,
    );
    
    // Load logo once and reuse
    final defaultLogo = await loadDefaultLogoBytes();
    pw.MemoryImage? cachedLogo;
    if (defaultLogo.isNotEmpty) {
      cachedLogo = pw.MemoryImage(defaultLogo);
    }

    // 1. Cover Page / Instructions
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Kutbi Paints: QR Sticker Batch Export',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Bullet(text: 'Total Stickers: ${qrs.length}'),
              pw.Bullet(text: 'Layout: ${columns}x$rows Grid per A4 sheet ($stickersPerPage per page)'),
              pw.Bullet(text: 'Batch ID: ${qrs.isNotEmpty ? qrs.first.batchId : "N/A"}'),
              pw.SizedBox(height: 30),
              pw.Text('Printing Instructions for Buckets:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
              pw.SizedBox(height: 10),
              pw.Bullet(text: 'Use Vinyl or Water-resistant adhesive paper.'),
              pw.Bullet(text: 'Print at 100% Scale (Do NOT use "Scale to Fit").'),
              pw.Bullet(text: 'Select "High Quality" print setting for QR clarity.'),
              pw.Bullet(text: 'Wipe bucket surface with alcohol before applying.'),
            ],
          );
        },
      ),
    );

    // Calculate sticker size based on columns
    final pageWidth = PdfPageFormat.a4.width - 30; // margins
    final stickerSize = (pageWidth / columns).clamp(50.0, 200.0);
    
    // 2. Sticker Pages (Paginated)
    final totalPages = (qrs.length / stickersPerPage).ceil();
    
    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIdx = pageIndex * stickersPerPage;
      final endIdx = (startIdx + stickersPerPage < qrs.length) ? startIdx + stickersPerPage : qrs.length;
      final batch = qrs.sublist(startIdx, endIdx);
      final currentPage = pageIndex + 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          build: (context) {
            return pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: List.generate(rows, (rowIndex) {
                      final rowStart = rowIndex * columns;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                          children: List.generate(columns, (colIndex) {
                            final idx = rowStart + colIndex;
                            if (idx < batch.length) {
                              return pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 2.5),
                                child: _buildPdfSticker(qr: batch[idx], stickerSize: stickerSize, cachedLogo: cachedLogo),
                              );
                            }
                            return pw.SizedBox(width: stickerSize, height: stickerSize);
                          }),
                        ),
                      );
                    }),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Page $currentPage of $totalPages',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildPdfSticker({
    required QRCodeModel qr,
    required double stickerSize,
    pw.MemoryImage? cachedLogo,
  }) {
    final palette = qrStickerPaletteMap[qr.colorScheme] ?? qrStickerPalettes.first;
    
    // Use custom logo if available, otherwise use cached default
    pw.ImageProvider? logoImage;
    if (qr.customLogoBase64 != null && qr.customLogoBase64!.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(qr.customLogoBase64!));
      } catch (_) {}
    }
    logoImage ??= cachedLogo;

    final primary = PdfColor.fromInt(palette.primary.toARGB32());
    final secondary = PdfColor.fromInt(palette.secondary.toARGB32());
    final textColor = PdfColor.fromInt(palette.text.toARGB32());
    final accent = PdfColor.fromInt(palette.accent.toARGB32());

    // Scale factors based on sticker size
    final scale = stickerSize / 200.0;
    final qrSize = (80 * scale).clamp(40.0, 95.0);
    final fontSize = (12 * scale).clamp(6.0, 15.0);
    final smallFontSize = (8 * scale).clamp(5.0, 9.0);
    final idFontSize = (10 * scale).clamp(6.0, 11.0); // Larger ID font
    final logoSize = (24 * scale).clamp(14.0, 28.0);
    final padding = (8 * scale).clamp(4.0, 10.0);

    return pw.Container(
      width: stickerSize,
      height: stickerSize,
      padding: pw.EdgeInsets.all(padding),
      decoration: pw.BoxDecoration(
        color: secondary,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: accent, width: 2.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: logoSize,
                  height: logoSize,
                  margin: const pw.EdgeInsets.only(right: 4),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              pw.Text(
                'Kutbi Paints',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),

          // QR Code
          pw.Container(
            padding: pw.EdgeInsets.all(padding / 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qr.qrValue,
              width: qrSize,
              height: qrSize,
              color: PdfColors.black,
            ),
          ),

          // Info Section
          pw.Column(
            children: [
              pw.Text(
                qr.message ?? 'Scan with Kutbi app',
                style: pw.TextStyle(
                  fontSize: smallFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ID: ${qr.id.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: idFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                  font: pw.Font.courierBold(),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: padding, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Text(
                  '${qr.points} Points',
                  style: pw.TextStyle(
                    fontSize: smallFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
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

