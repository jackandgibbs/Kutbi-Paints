import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../models/return_model.dart';
import '../models/custom_invoice_model.dart';

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
    double? subtotal,
    double discountAmount = 0.0,
    String? discountName,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    final totalAmount = customTotal ?? order.totalAmount;
    final displaySubtotal = subtotal ?? totalAmount;
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
              // Top Title: ESTIMATE
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey800, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'ESTIMATE',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 16,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),

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
                        child: pw.Text('₹ ${displaySubtotal.toStringAsFixed(0)}', style: pw.TextStyle(font: boldFont, fontSize: 11), textAlign: pw.TextAlign.right),
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
                        if (discountAmount > 0) ...[
                          _summaryRow('Subtotal', '₹ ${displaySubtotal.toStringAsFixed(0)}', font),
                          _summaryRow('Discount (${discountName ?? 'Offer'})', '- ₹ ${discountAmount.toStringAsFixed(0)}', font),
                        ],
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

  static Future<Uint8List> generateReturnBill({
    required ReturnRequestModel returnRequest,
    required OrderModel? order,
    required String painterName,
    required String painterPhone,
    required List<Map<String, dynamic>> items,
    double? customRefundTotal,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    final totalRefund = customRefundTotal ?? returnRequest.refundAmount;
    final billDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final retId = returnRequest.displayId;
    final orderId = order != null ? '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}' : '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header: RETURN BILL / CREDIT NOTE
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red800, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'RETURN BILL / CREDIT NOTE',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 15,
                      color: PdfColors.red800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $billDate', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Text('Return ID: $retId', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                ],
              ),
              if (orderId.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Original Order: $orderId', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
              ],

              pw.SizedBox(height: 18),

              // Return From Section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    child: pw.Text('RETURN FROM', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(painterName, style: pw.TextStyle(font: boldFont, fontSize: 13)),
                  pw.Text('Mobile : $painterPhone', style: pw.TextStyle(font: font, fontSize: 11)),
                  if (returnRequest.reason.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Reason: ${returnRequest.reason}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ],
              ),

              pw.SizedBox(height: 18),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableHeaderCell('S.NO.', boldFont),
                      _tableHeaderCell('RETURNED ITEM', boldFont),
                      _tableHeaderCell('SIZE', boldFont),
                      _tableHeaderCell('QTY.', boldFont),
                      _tableHeaderCell('RATE', boldFont),
                      _tableHeaderCell('REFUND', boldFont),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                    final amount = (item['amount'] as num?)?.toDouble() ?? (qty * rate);
                    final productName = (item['product_name'] ??
                            item['name'] ??
                            item['productName'] ??
                            item['item_name'] ??
                            'Returned Item')
                        .toString();
                    final bucketSize = (item['bucket_size'] ??
                            item['bucketSize'] ??
                            item['size'] ??
                            '')
                        .toString();

                    return pw.TableRow(
                      children: [
                        _tableCell(index.toString(), font, align: pw.TextAlign.center),
                        _tableCell(productName, font),
                        _tableCell(bucketSize, font, align: pw.TextAlign.center),
                        _tableCell(qty.toString(), font, align: pw.TextAlign.center),
                        _tableCell('₹${rate.toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                        _tableCell('₹${amount.toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Summary Section
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Refund Amount:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                          pw.Text('₹ ${totalRefund.toStringAsFixed(0)}', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.green800)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Refund Method:', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                          pw.Text(returnRequest.refundMethod.replaceAll('_', ' ').toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Authorized Signature', style: pw.TextStyle(font: font, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateCustomInvoicePdf(CustomInvoiceModel invoice) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    final billDate = DateFormat('dd MMM yyyy').format(invoice.date);
    final totalQty = invoice.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final isPurchase = invoice.isPurchase;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Title: ESTIMATE / RETURN BILL
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: isPurchase ? PdfColors.grey800 : PdfColors.red800,
                      width: 1.5,
                    ),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    isPurchase ? 'ESTIMATE / INVOICE' : 'RETURN BILL / CREDIT NOTE',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 15,
                      color: isPurchase ? PdfColors.grey900 : PdfColors.red800,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),

              // Header with Invoice Number and Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $billDate', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Text(
                    '${isPurchase ? 'Invoice' : 'Credit Note'} No: ${invoice.invoiceNumber}',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // Party Details Section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 130,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: isPurchase ? PdfColors.grey200 : PdfColors.red50,
                    ),
                    child: pw.Text(
                      isPurchase ? 'BILL TO' : 'RETURN FROM',
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.painterName.isNotEmpty ? invoice.painterName : 'Customer / Painter',
                    style: pw.TextStyle(font: boldFont, fontSize: 13),
                  ),
                  if (invoice.painterPhone.isNotEmpty)
                    pw.Text('Mobile : ${invoice.painterPhone}', style: pw.TextStyle(font: font, fontSize: 11)),
                  if (invoice.notes.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Notes: ${invoice.notes}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ],
              ),

              pw.SizedBox(height: 18),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(65),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FixedColumnWidth(75),
                  5: const pw.FixedColumnWidth(85),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isPurchase ? PdfColors.grey200 : PdfColors.grey100,
                    ),
                    children: [
                      _tableHeaderCell('S.NO.', boldFont),
                      _tableHeaderCell(isPurchase ? 'ITEM DESCRIPTION' : 'RETURNED ITEM', boldFont),
                      _tableHeaderCell('SIZE', boldFont),
                      _tableHeaderCell('QTY.', boldFont),
                      _tableHeaderCell('RATE', boldFont),
                      _tableHeaderCell(isPurchase ? 'AMOUNT' : 'REFUND', boldFont),
                    ],
                  ),
                  ...invoice.items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _tableCell(index.toString(), font, align: pw.TextAlign.center),
                        _tableCell(
                          item.shade != null && item.shade!.isNotEmpty
                              ? '${item.productName}\nShade: ${item.shade}'
                              : item.productName,
                          font,
                        ),
                        _tableCell(item.bucketSize, font, align: pw.TextAlign.center),
                        _tableCell(item.quantity.toString(), font, align: pw.TextAlign.center),
                        _tableCell('₹ ${item.rate.toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                        _tableCell('₹ ${item.amount.toStringAsFixed(0)}', font, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              // Subtotal row
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(65),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FixedColumnWidth(75),
                  5: const pw.FixedColumnWidth(85),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('TOTAL QTY / SUBTOTAL', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('$totalQty PCS', style: pw.TextStyle(font: boldFont, fontSize: 10), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('₹ ${invoice.subtotal.toStringAsFixed(0)}', style: pw.TextStyle(font: boldFont, fontSize: 10), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // Summary / Footer
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms / Notes
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TERMS & NOTES', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        if (isPurchase) ...[
                          pw.Text('1. Goods once sold will not be taken back without valid bill.', style: pw.TextStyle(font: font, fontSize: 8)),
                          pw.Text('2. All disputes are subject to Dahod jurisdiction only.', style: pw.TextStyle(font: font, fontSize: 8)),
                        ] else ...[
                          pw.Text('1. Return credit processed for verified inventory.', style: pw.TextStyle(font: font, fontSize: 8)),
                          pw.Text('2. Retain this credit slip for accounting reference.', style: pw.TextStyle(font: font, fontSize: 8)),
                        ],
                      ],
                    ),
                  ),
                  // Totals Box
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      children: [
                        if (invoice.discount > 0) ...[
                          _summaryRow('Subtotal', '₹ ${invoice.subtotal.toStringAsFixed(0)}', font),
                          _summaryRow('Discount / Adjustment', '- ₹ ${invoice.discount.toStringAsFixed(0)}', font),
                        ],
                        _summaryRow(
                          isPurchase ? 'Grand Total' : 'Net Refund Total',
                          '₹ ${invoice.totalAmount.toStringAsFixed(0)}',
                          boldFont,
                          isBold: true,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Total in words', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text(_getNumberInWords(invoice.totalAmount.toInt()), style: pw.TextStyle(font: font, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Bottom signature
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Authorized Signature', style: pw.TextStyle(font: font, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}

