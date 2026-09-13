import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_invoice_model.dart';
export '../models/custom_invoice_model.dart';

class CustomInvoiceService extends ChangeNotifier {
  static const _storageKey = 'kutbi_custom_invoices_v1';

  List<CustomInvoiceModel> _invoices = [];
  bool _isLoading = true;

  CustomInvoiceService() {
    _loadFromStorage();
  }

  List<CustomInvoiceModel> get invoices => List.unmodifiable(_invoices);
  bool get isLoading => _isLoading;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getString(_storageKey);
      if (rawData != null && rawData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawData) as List<dynamic>;
        _invoices = decoded
            .map((item) => CustomInvoiceModel.fromJson(item as Map<String, dynamic>))
            .toList();
        // Sort newest first by default
        _invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('Error loading custom invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_invoices.map((inv) => inv.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving custom invoices: $e');
    }
  }

  String generateInvoiceNumber(String billType) {
    final prefix = billType.toLowerCase() == 'return' ? 'RET' : 'INV';
    final count = _invoices.where((inv) => inv.billType.toLowerCase() == billType.toLowerCase()).length + 1;
    final rand = 1000 + count;
    return '$prefix-$rand';
  }

  Future<void> addInvoice(CustomInvoiceModel invoice) async {
    _invoices.insert(0, invoice);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateInvoice(CustomInvoiceModel updated) async {
    final index = _invoices.indexWhere((inv) => inv.id == updated.id);
    if (index != -1) {
      _invoices[index] = updated;
      notifyListeners();
      await _saveToStorage();
    } else {
      await addInvoice(updated);
    }
  }

  Future<void> deleteInvoice(String id) async {
    _invoices.removeWhere((inv) => inv.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  CustomInvoiceModel? getById(String id) {
    try {
      return _invoices.firstWhere((inv) => inv.id == id);
    } catch (_) {
      return null;
    }
  }

  CustomInvoiceModel? getByOrderId(String orderId) {
    try {
      return _invoices.firstWhere((inv) => inv.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateOrderStatusForInvoice(String orderId, String newStatus) async {
    final index = _invoices.indexWhere((inv) => inv.orderId == orderId);
    if (index != -1) {
      _invoices[index] = _invoices[index].copyWith(orderStatus: newStatus);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> updateInvoiceStatus(String invoiceId, String newStatus) async {
    final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index != -1) {
      _invoices[index] = _invoices[index].copyWith(orderStatus: newStatus);
      notifyListeners();
      await _saveToStorage();
    }
  }
}

final customInvoiceServiceProvider = ChangeNotifierProvider<CustomInvoiceService>((ref) {
  return CustomInvoiceService();
});
