import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order_model.dart';
import '../models/ledger_model.dart';
import 'data_service.dart';

class ReportService {
  static final DateFormat _df = DateFormat('yyyy-MM-dd HH:mm');

  /// Exports orders to a CSV file and shares it
  static Future<void> exportOrdersCSV(List<OrderModel> orders, DataService ds) async {
    if (orders.isEmpty) return;

    List<List<dynamic>> rows = [];
    
    // Header
    rows.add([
      "Order ID", 
      "Date", 
      "Painter Name", 
      "Painter Phone",
      "Brand", 
      "Items Count", 
      "Total Amount", 
      "Status", 
      "Site Location"
    ]);
    
    for (var order in orders) {
      final painter = ds.getUserById(order.painterId);
      rows.add([
        order.id.length > 8 ? order.id.substring(0, 8) : order.id,
        _df.format(order.createdAt),
        painter?.name ?? 'Unknown',
        painter?.phone ?? 'N/A',
        order.brand,
        order.items.length,
        order.totalAmount,
        order.status,
        order.siteLocation.replaceAll('\n', ' ')
      ]);
    }
    
    String csv = const ListToCsvConverter().convert(rows);
    await _saveAndShare(csv, "Orders_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv");
  }

  /// Exports ledger entries (Udhaari) to a CSV file and shares it
  static Future<void> exportUdhaariCSV(List<LedgerEntry> ledger, DataService ds) async {
    if (ledger.isEmpty) return;

    List<List<dynamic>> rows = [];
    
    // Header
    rows.add([
      "Date", 
      "Painter Name", 
      "Type", 
      "Amount", 
      "Note", 
      "Running Balance"
    ]);
    
    // Sort by date desc
    final sortedLedger = List<LedgerEntry>.from(ledger)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (var entry in sortedLedger) {
      final painter = ds.getUserById(entry.painterId);
      rows.add([
        _df.format(entry.createdAt),
        painter?.name ?? 'Unknown',
        entry.type.toUpperCase(),
        entry.amount,
        (entry.note ?? "").replaceAll('\n', ' '),
        entry.runningBalance
      ]);
    }
    
    String csv = const ListToCsvConverter().convert(rows);
    await _saveAndShare(csv, "Udhaari_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv");
  }

  /// Exports a simple PDF report for a painter's performance
  static Future<void> exportPainterPerformancePDF({
    required String painterName,
    required double totalSpend,
    required double goldSavings,
    required Map<String, double> brandBreakdown,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text("Painter Performance Report: $painterName")),
              pw.SizedBox(height: 20),
              pw.Text("Generated on: ${_df.format(DateTime.now())}"),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Summary Stats:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Bullet(text: "Total Life-time Spend: Rs. ${totalSpend.toStringAsFixed(2)}"),
              pw.Bullet(text: "Estimated Gold Savings: Rs. ${goldSavings.toStringAsFixed(2)}"),
              pw.SizedBox(height: 20),
              pw.Text("Brand breakdown:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ...brandBreakdown.entries.map((e) => pw.Bullet(text: "${e.key}: Rs. ${e.value.toStringAsFixed(2)}")),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text("Kutbi Paints - Wholesale Management System", style: pw.TextStyle(color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Performance_Report_${painterName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    await Share.shareXFiles([XFile(file.path)], text: 'Painter Performance Report');
  }

  /// Saves the string to a temporary file and opens the share dialog
  static Future<void> _saveAndShare(String content, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Kutbi Paints Data Export');
  }
}
