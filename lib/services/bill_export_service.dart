import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class BillExportService {
  static const _invoiceKey = 'kutbi_invoice_number';

  static Future<int> _getNextInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_invoiceKey) ?? 0;
    final next = (current % 100) + 1; // cycles 1 -> 100 -> 1
    await prefs.setInt(_invoiceKey, next);
    return next;
  }

  static Future<Uint8List> generateOrderBill({
    required OrderModel order,
    required String painterName,
    required String painterPhone,
    required List<Map<String, dynamic>> items,
    double? customTotal,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    final totalAmount = customTotal ?? order.totalAmount;
    final totalQty = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
    final invoiceNo = await _getNextInvoiceNumber();
    final invoiceStr = invoiceNo.toString().padLeft(2, '0');
    final billDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Invoice Number and Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $billDate', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Text('Invoice No: $invoiceStr', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                ],
              ),

              pw.SizedBox(height: 20),

              // Bill To Section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    child: pw.Text('BILL TO', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(painterName, style: pw.TextStyle(font: boldFont, fontSize: 13)),
                  pw.Text('Mobile : $painterPhone', style: pw.TextStyle(font: font, fontSize: 11)),
                ],
              ),

              pw.SizedBox(height: 20),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(80),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableHeaderCell('S.NO.', boldFont),
                      _tableHeaderCell('ITEMS', boldFont),
                      _tableHeaderCell('SIZE', boldFont),
                      _tableHeaderCell('QTY.', boldFont),
                      _tableHeaderCell('RATE', boldFont),
                      _tableHeaderCell('AMOUNT', boldFont),
                    ],
                  ),
                  // Table Rows
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    return pw.TableRow(
                      children: [
                        _tableCell((index + 1).toString(), font, align: pw.TextAlign.center),
                        _tableCell(item['name'], font),
                        _tableCell(item['bucketSize'] ?? '', font, align: pw.TextAlign.center),
                        _tableCell('${item['quantity']}', font, align: pw.TextAlign.center),
                        _tableCell('₹${(item['rate'] as num).toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                        _tableCell('₹${(item['amount'] as num).toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              // Summary Section
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('SUBTOTAL', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('$totalQty PCS', style: pw.TextStyle(font: boldFont, fontSize: 11), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('₹ ${totalAmount.toStringAsFixed(0)}', style: pw.TextStyle(font: boldFont, fontSize: 11), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total Section Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Terms
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TERMS AND CONDITIONS', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text('1. Goods once sold will not be taken back or exchanged', style: pw.TextStyle(font: font, fontSize: 8)),
                        pw.Text('2. All disputes are subject to Dahod jurisdiction only', style: pw.TextStyle(font: font, fontSize: 8)),
                      ],
                    ),
                  ),
                  // Right: Totals
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      children: [
                        _summaryRow('Total Amount', '₹ ${totalAmount.toStringAsFixed(0)}', boldFont, isBold: true),
                        _summaryRow('Received Amount', '₹ 0', font),
                        pw.SizedBox(height: 10),
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Total Amount (in words)', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text(_getNumberInWords(totalAmount.toInt()), style: pw.TextStyle(font: font, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _tableCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10), textAlign: align),
    );
  }

  static pw.Widget _summaryRow(String label, String value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    );
  }

  static String _getNumberInWords(int amount) {
    if (amount == 0) return 'Zero Rupees Only';
    return '${amount.toString()} Rupees Only'; 
  }
}
