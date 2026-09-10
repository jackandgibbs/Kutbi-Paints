import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

/// Provides offline caching and sync queue for the app.
/// Caches products and orders locally using Hive.
/// Queues pending writes (e.g. orders placed offline) and syncs them
/// when connectivity is restored.
class OfflineService extends ChangeNotifier {
  static const _productsBox = 'products_cache';
  static const _ordersBox = 'orders_cache';
  static const _pendingBox = 'pending_writes';

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  OfflineService() {
    _initConnectivity();
  }

  /// Initialize connectivity monitoring
  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    notifyListeners();

    Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      notifyListeners();

      // Auto-sync when coming back online
      if (wasOffline && _isOnline) {
        syncPendingWrites();
      }
    });
  }

  /// Initialize Hive boxes
  static Future<void> init() async {
    try {
      await Hive.initFlutter('kutbi_cache');
      await _openBoxSafe(_productsBox);
      await _openBoxSafe(_ordersBox);
      await _openBoxSafe(_pendingBox);
    } catch (e) {
      debugPrint('OfflineService init error: $e');
    }
  }

  static Future<void> _openBoxSafe(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    } catch (e) {
      debugPrint('Failed to open Hive box $name: $e');
      try {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox(name);
      } catch (inner) {
        debugPrint('Could not recover Hive box $name: $inner');
      }
    }
  }

  static Box? _getBox(String name) {
    if (Hive.isBoxOpen(name)) {
      try {
        return Hive.box(name);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ─── CACHE PRODUCTS ─────────────────────────────────────────────
  Future<void> cacheProducts(List<ProductModel> products) async {
    final box = _getBox(_productsBox);
    if (box == null) return;
    await box.clear();
    for (final p in products) {
      await box.put(p.id, jsonEncode(p.toJson()));
    }
  }

  List<ProductModel> getCachedProducts() {
    final box = _getBox(_productsBox);
    if (box == null) return [];
    return box.values.map((v) {
      return ProductModel.fromJson(jsonDecode(v as String));
    }).toList();
  }

  // ─── CACHE ORDERS ───────────────────────────────────────────────
  Future<void> cacheOrders(List<OrderModel> orders) async {
    final box = _getBox(_ordersBox);
    if (box == null) return;
    await box.clear();
    for (final o in orders) {
      await box.put(o.id, jsonEncode(o.toJson()));
    }
  }

  List<OrderModel> getCachedOrders() {
    final box = _getBox(_ordersBox);
    if (box == null) return [];
    return box.values.map((v) {
      return OrderModel.fromJson(jsonDecode(v as String));
    }).toList();
  }

  // ─── PENDING WRITES QUEUE ───────────────────────────────────────
  Future<void> queueOrder(OrderModel order) async {
    final box = _getBox(_pendingBox);
    if (box == null) return;
    await box.add(jsonEncode({
      'type': 'order',
      'data': order.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    }));
    notifyListeners();
  }

  int get pendingWritesCount => _getBox(_pendingBox)?.length ?? 0;

  /// Sync all pending writes to server
  Future<void> syncPendingWrites() async {
    if (!_isOnline) return;
    final box = _getBox(_pendingBox);
    if (box == null || box.isEmpty) return;

    debugPrint('OfflineService: Syncing ${box.length} pending writes...');
    // Pending writes are synced by DataService when it calls refresh()
    // This is a signal to the UI that sync is happening
    notifyListeners();
  }

  List<Map<String, dynamic>> getPendingWrites() {
    final box = _getBox(_pendingBox);
    if (box == null) return [];
    return box.values.map((v) {
      return jsonDecode(v as String) as Map<String, dynamic>;
    }).toList();
  }

  Future<void> clearPendingWrites() async {
    final box = _getBox(_pendingBox);
    if (box != null) {
      await box.clear();
    }
    notifyListeners();
  }
}
