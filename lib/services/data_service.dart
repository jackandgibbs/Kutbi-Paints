import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/goal_model.dart';
import '../models/ledger_model.dart';
import '../models/message_model.dart';
import '../models/promotion_model.dart';
import '../models/referral_model.dart';
import '../models/qr_code_model.dart';
import '../models/milestone_model.dart';
import '../models/brand_model.dart';
import '../models/banner_model.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';

/// Centralized data service — uses Supabase for persistence.
/// Keeps in-memory cache for fast reads, syncs writes to Supabase.
class DataService extends ChangeNotifier {
  // In-memory cache
  List<UserModel> _users = [];
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<GoalModel> _goals = [];
  List<RewardModel> _rewards = [];
  List<LedgerEntry> _ledger = [];
  List<MessageModel> _messages = [];
  List<PromotionModel> _promotions = [];
  final List<ReferralModel> _referrals = [];
  List<QRCodeModel> _qrCodes = [];
  List<MilestoneModel> _milestones = [];
  List<Map<String, dynamic>> _milestoneAchievements = [];
  List<BrandModel> _brands = [];
  List<Map<String, dynamic>> _brandCategories = [];
  List<BannerModel> _banners = [];
  String _adminQrUrl = '';
  String _minAppVersion = '1.0.0';
  String _forceUpdateUrl = 'https://kutbi-paints.com/update';
  bool _forceUpdateEnabled = false;
  bool _isLoaded = false;
  bool _updateRequired = false;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;

  static const _uuid = Uuid();

  final SupabaseClient _sb = Supabase.instance.client;

  DataService() {
    _loadFromSupabase();
    _initMessageStream();
    _initOrdersStream();
    _initProductsStream();
  }

  bool get isLoaded => _isLoaded;
  String get adminQrUrl => _adminQrUrl;
  String get forceUpdateUrl => _forceUpdateUrl;
  bool get forceUpdateEnabled => _forceUpdateEnabled;
  String get minAppVersion => _minAppVersion;
  bool get updateRequired => _updateRequired;

  String _normalizeLabel(String value) => value.trim().toLowerCase();

  List<UserModel> get users => _users;
  List<UserModel> get painters => _users.where((u) => u.isPainter).toList();
  List<UserModel> get paintersWithPendingBank =>
      _users.where((u) => u.isPainter && u.bankStatus == 'pending').toList();

  // Cached stats for performance
  int get activeQRCount => _qrCodes.where((qr) => qr.status == 'active').length;
  int get usedQRCount => _qrCodes.where((qr) => qr.status == 'used').length;
  int get totalPointsIssued => _qrCodes.fold<int>(0, (sum, qr) => sum + qr.points);

  /// Load all data from Supabase into memory
  Future<void> _loadFromSupabase() async {
    try {
      debugPrint('DataService: Loading users from Supabase...');
      final usersData = await _sb.from('users').select();
      _users = (usersData as List).map((u) => UserModel.fromJson(u)).toList();
      debugPrint('DataService: ${_users.length} users loaded');
      
      // Secondary data loads continue in background
      await _loadSecondaryData();

      // Check version after settings are loaded
      await checkAppVersion();

      // CRITICAL: We mark as loaded as soon as users and basic settings are available
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading critical data from Supabase: $e');
      _isLoaded = false;
      notifyListeners();
    }
  }

  Future<void> _loadSecondaryData() async {
    // Wrap each in individual try-catch to ensure one doesn't block others
    try {
      final settings = await _sb.from('app_settings').select();
      final qrEntry = settings.where((s) => s['key'] == 'admin_qr_url').toList();
      if (qrEntry.isNotEmpty) _adminQrUrl = qrEntry.first['value'] ?? '';
      
      final verEntry = settings.where((s) => s['key'] == 'min_app_version').toList();
      if (verEntry.isNotEmpty) _minAppVersion = verEntry.first['value'] ?? '1.0.0';

      final forceEnabledEntry = settings.where((s) => s['key'] == 'force_update_enabled').toList();
      if (forceEnabledEntry.isNotEmpty) _forceUpdateEnabled = forceEnabledEntry.first['value'] == 'true';

      final forceUrlEntry = settings.where((s) => s['key'] == 'force_update_url').toList();
      if (forceUrlEntry.isNotEmpty) _forceUpdateUrl = forceUrlEntry.first['value'] ?? 'https://kutbi-paints.com/update';
    } catch (e) { debugPrint('Error loading app_settings: $e'); }

    try {
      final productsData = await _sb.from('products').select();
      _products = (productsData as List).map((p) => ProductModel.fromJson(p)).toList();
    } catch (e) { debugPrint('Error loading products: $e'); }

    try {
      final ordersData = await _sb.from('orders').select();
      _orders = (ordersData as List).map((o) => OrderModel.fromJson(o)).toList();
    } catch (e) { debugPrint('Error loading orders: $e'); }

    try {
      final goalsData = await _sb.from('goals').select();
      _goals = (goalsData as List).map((g) => GoalModel.fromJson(g)).toList();
    } catch (e) { debugPrint('Error loading goals: $e'); }

    try {
      final rewardsData = await _sb.from('rewards').select();
      _rewards = (rewardsData as List).map((r) => RewardModel.fromJson(r)).toList();
    } catch (e) { debugPrint('Error loading rewards: $e'); }

    try {
      final ledgerData = await _sb.from('ledger').select();
      _ledger = (ledgerData as List).map((l) => LedgerEntry.fromJson(l)).toList();
    } catch (e) { debugPrint('Error loading ledger: $e'); }

    try {
      final messagesData = await _sb.from('messages').select();
      _messages = messagesData.map((e) => MessageModel.fromJson(e)).toList();
    } catch (e) { debugPrint('Error loading messages: $e'); }

    try {
      final promosData = await _sb.from('promotions').select();
      _promotions = promosData.map((e) => PromotionModel.fromJson(e)).toList();
    } catch (e) { debugPrint('Error loading promotions: $e'); }

    try {
      final qrData = await _sb.from('qr_codes').select();
      _qrCodes = qrData.map((e) => QRCodeModel.fromJson(e)).toList();
    } catch (e) { debugPrint('Error loading QR codes: $e'); }

    try {
      final milestonesData = await _sb.from('milestones').select();
      _milestones = milestonesData.map((e) => MilestoneModel.fromJson(e)).toList();
    } catch (e) { debugPrint('Error loading milestones: $e'); }

    try {
      final achievementsData = await _sb.from('milestone_achievements').select();
      _milestoneAchievements = List<Map<String, dynamic>>.from(achievementsData);
    } catch (e) { debugPrint('Error loading milestone achievements: $e'); }

    try {
      final brandsData = await _sb.from('brands').select().order('sort_order');
      _brands = (brandsData as List).map((b) => BrandModel.fromJson(b)).toList();
    } catch (e) { debugPrint('Error loading brands: $e'); }

    try {
      final bcData = await _sb.from('brand_categories').select();
      _brandCategories = List<Map<String, dynamic>>.from(bcData);
    } catch (e) { debugPrint('Error loading brand_categories: $e'); }

    try {
      final bannersData = await _sb.from('banners').select().order('sort_order');
      _banners = (bannersData as List).map((b) => BannerModel.fromJson(b)).toList();
    } catch (e) { debugPrint('Error loading banners: $e'); }

    try {
      final historyData = await _sb.from('app_settings').select().eq('key', 'points_history').maybeSingle();
      if (historyData != null && historyData['value'] != null) {
        _pointsHistory = List<Map<String, dynamic>>.from(historyData['value'] as List);
      }
    } catch (e) { debugPrint('Error loading points history: $e'); }

    notifyListeners();
  }

  /// Reload all data from Supabase (call after external changes)
  Future<void> refresh() async {
    _isLoaded = false;
    notifyListeners();
    await _loadFromSupabase();
  }

  Future<void> checkAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Simple semantic version comparison (v1.v2.v3)
      _updateRequired = _isVersionLower(currentVersion, _minAppVersion);
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }

  bool _isVersionLower(String current, String min) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minParts = min.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateAdminQr(String url) async {
    _adminQrUrl = url;
    notifyListeners();
    try {
      await _sb.from('app_settings').upsert({
        'key': 'admin_qr_url',
        'value': url,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');
    } catch (e) {
      debugPrint('Error updating admin QR: $e');
      throw Exception('Failed to update admin QR: $e');
    }
  }

  Future<void> updateGlobalSettings({
    required bool forceUpdate, 
    required String url,
    required String minVersion,
  }) async {
    _forceUpdateEnabled = forceUpdate;
    _forceUpdateUrl = url;
    _minAppVersion = minVersion;
    notifyListeners();
    try {
      await _sb.from('app_settings').upsert([
        {
          'key': 'force_update_enabled',
          'value': forceUpdate.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'key': 'force_update_url',
          'value': url,
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'key': 'min_app_version',
          'value': minVersion,
          'updated_at': DateTime.now().toIso8601String(),
        }
      ], onConflict: 'key');
      
      // Re-check version locally
      await checkAppVersion();
    } catch (e) {
      debugPrint('Error updating global settings: $e');
      throw Exception('Failed to update settings: $e');
    }
  }

  Future<void> updateUserAppVersion(String userId, String version) async {
    try {
      // Skip database update if column doesn't exist
      // await _sb.from('users').update({
      //   'app_version': version,
      //   'updated_at': DateTime.now().toIso8601String(),
      // }).eq('id', userId);
      
      // Update local list only
      final idx = _users.indexWhere((u) => u.id == userId);
      if (idx != -1) {
        _users[idx] = _users[idx].copyWith(appVersion: version);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating user app version: $e');
    }
  }

  Map<String, dynamic> getGlobalStats() {
    // Total Users
    final totalPainters = _users.where((u) => u.isPainter).length;
    
    // Total Orders
    final totalOrders = _orders.length;
    
    // Revenue (Delivered orders)
    final revenue = _orders
        .where((o) => o.status == 'delivered')
        .fold(0.0, (sum, o) => sum + o.totalAmount);
        
    // Total Outstanding Udhaari (Across all painters)
    double totalUdhaari = 0;
    final balanceMap = <String, double>{};
    for (final e in _ledger) {
      balanceMap.putIfAbsent(e.painterId, () => 0.0);
      if (e.isCredit) {
        balanceMap[e.painterId] = balanceMap[e.painterId]! + e.amount;
      } else {
        balanceMap[e.painterId] = balanceMap[e.painterId]! - e.amount;
      }
    }
    for (final bal in balanceMap.values) {
      if (bal > 0) totalUdhaari += bal;
    }

    return {
      'totalUsers': totalPainters,
      'totalOrders': totalOrders,
      'revenue': revenue,
      'totalUdhaari': totalUdhaari,
      'activeUdhaariCount': getPaintersWithDebtCount(),
    };
  }

  // ─── AUTH ──────────────────────────────────────────────────────
  UserModel? login(String phone, String pin) {
    try {
      return _users.firstWhere(
        (u) => u.phone == phone && u.pin == pin,
      );
    } catch (_) {
      return null;
    }
  }

  UserModel? getUserByEmail(String email) {
    try {
      return _users.firstWhere((u) => u.email.toLowerCase() == email.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  UserModel? findUserByPhone(String phone) {
    try {
      return _users.firstWhere((u) => u.phone == phone && u.role == 'painter');
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserPinByPhone(String phone, String newPin) async {
    final i = _users.indexWhere((u) => u.phone == phone && u.role == 'painter');
    if (i != -1) {
      final user = _users[i];
      _users[i] = user.copyWith(
        pin: newPin,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      
      try {
        await _sb.from('users').update({
          'pin': newPin,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (e) {
        debugPrint('Error updating user PIN in Supabase: $e');
        rethrow;
      }
    } else {
      throw Exception('User not found with phone: $phone');
    }
  }

  Future<UserModel> register({
    required String name,
    required String phone,
    required String email,
    required String pin,
    required String businessName,
    required String businessAddress,
    String? referralCode,
  }) async {
    final user = UserModel(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      email: email,
      pin: pin,
      role: 'painter',
      status: 'inactive',
      businessName: businessName,
      businessAddress: businessAddress,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      referralCode: _generateInitialReferralCode(name),
    );
    // Persist to Supabase FIRST
    try {
      await _sb.from('users').insert(user.toJson());
      // Only add to local list IF Supabase insertion succeeds
      _users.add(user);
      notifyListeners();
    } catch (e) {
      debugPrint('Error inserting user: $e');
      rethrow; // Propagate to AuthNotifier
    }

    if (referralCode != null && referralCode.isNotEmpty) {
      _applyReferralCode(referralCode, user.id);
    }

    return user;
  }

  // ─── USERS ─────────────────────────────────────────────────────
  List<UserModel> getAllPainters() {
    return _users.where((u) => u.role == 'painter').toList();
  }

  List<UserModel> getAdmins() {
    return _users.where((u) => u.role == 'admin').toList();
  }

  List<UserModel> getPaintersByStatus(String status) {
    return _users
        .where((u) => u.role == 'painter' && u.status == status)
        .toList();
  }

  UserModel? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserStatus(String userId, String status) async {
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i] = _users[i].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return _sb.from('users').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId).catchError((e) {
        debugPrint('Error updating user status: $e');
        throw Exception('Failed to update user status: $e');
      });
    }
  }

  Future<void> approveUser(String userId, String role) async {
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i] = _users[i].copyWith(
        status: 'active',
        role: role,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('users').update({
          'status': 'active',
          'role': role,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (e) {
        debugPrint('Error approving user: $e');
        throw Exception('Failed to approve user: $e');
      }
    }
  }

  Future<void> updateUserTier(String userId, String tier) async {
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i] = _users[i].copyWith(
        tier: tier,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return _sb.from('users').update({
        'tier': tier,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId).catchError((e) {
        debugPrint('Error updating user tier: $e');
        throw Exception('Failed to update user tier: $e');
      });
    }
  }

  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.id == userId);
    notifyListeners();
    return _sb.from('users').delete().eq('id', userId).catchError((e) {
      debugPrint('Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    });
  }

  Future<UserModel> addPainter({
    required String name,
    required String phone,
    required String email,
    required String pin,
    required String businessName,
    required String businessAddress,
    String tier = 'silver',
  }) async {
    final user = UserModel(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      email: email,
      pin: pin,
      role: 'painter',
      status: 'active',
      businessName: businessName,
      businessAddress: businessAddress,
      tier: tier,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    // Persist to Supabase FIRST
    try {
      await _sb.from('users').insert(user.toJson());
      _users.add(user);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding painter: $e');
      rethrow;
    }
    return user;
  }

  // ─── PRODUCTS ──────────────────────────────────────────────────
  List<ProductModel> getAllProducts() => _products;

  List<ProductModel> getProductsWithLowStockState({String? brand}) {
    if (brand != null) {
      final normalizedBrand = _normalizeLabel(brand);
      return _products
          .where((p) => _normalizeLabel(p.brand) == normalizedBrand)
          .toList();
    }
    return _products;
  }

  List<ProductModel> getProductsByBrand(String brand) {
    final normalizedBrand = _normalizeLabel(brand);
    return _products
        .where((p) => _normalizeLabel(p.brand) == normalizedBrand)
        .toList();
  }

  List<ProductModel> searchProducts(String query) {
    final q = query.toLowerCase();
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.colorCode.toLowerCase().contains(q) ||
          p.colorName.toLowerCase().contains(q);
    }).toList();
  }

  List<ProductModel> getLowStockProducts() {
    return _products.where((p) => p.isLowStock).toList();
  }

  ProductModel? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }



  Future<void> updateProduct(ProductModel product) async {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i != -1) {
      await _sb.from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .catchError((e) {
        debugPrint('Error updating product: $e');
        throw Exception('Failed to update product: $e');
      });
      _products[i] = product;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    return _sb.from('products').delete().eq('id', productId).catchError((e) {
      debugPrint('Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
    });
  }


  List<ProductModel> getProductsByCategory(String brand, String category) {
    final normalizedBrand = _normalizeLabel(brand);
    final normalizedCategory = _normalizeLabel(category);
    return _products.where((p) =>
        _normalizeLabel(p.brand) == normalizedBrand &&
        _normalizeLabel(p.category) == normalizedCategory).toList();
  }

  List<String> getCategoriesForBrand(String brand) {
    final normalizedBrand = _normalizeLabel(brand);
    return _products
        .where((p) => _normalizeLabel(p.brand) == normalizedBrand)
        .map((p) => p.category)
        .toSet()
        .toList();
  }

  Map<String, List<ProductModel>> getProductsGroupedBySubCategory(
      String brand, String category) {
    final filtered = getProductsByCategory(brand, category);
    final grouped = <String, List<ProductModel>>{};
    for (final p in filtered) {
      grouped.putIfAbsent(p.subCategory, () => []).add(p);
    }
    return grouped;
  }

  Future<void> updateStock(String productId, int newStock) async {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i != -1) {
      _products[i] = _products[i].copyWith(
        stockLevel: newStock,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return _sb.from('products').update({
        'stock_level': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId).catchError((e) {
        debugPrint('Error updating stock: $e');
        throw Exception('Failed to update stock: $e');
      });
    }
  }

  Future<void> updateVariantStock(String productId, Map<String, int> variantStock) async {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i != -1) {
      _products[i] = _products[i].copyWith(
        variantStock: variantStock,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('products').update({
          'variant_stock': variantStock,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);
      } catch (e) {
        debugPrint('Error updating variant stock: $e');
        throw Exception('Failed to update variant stock: $e');
      }
    }
  }

  /// Toggle a product's out-of-stock status
  Future<void> toggleOutOfStock(String productId, bool outOfStock) async {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i != -1) {
      _products[i] = _products[i].copyWith(
        isOutOfStock: outOfStock,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('products').update({
          'is_out_of_stock': outOfStock,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);
      } catch (e) {
        debugPrint('Error toggling out of stock: $e');
        throw Exception('Failed to toggle out of stock: $e');
      }
    }
  }

  // ─── ORDERS ────────────────────────────────────────────────────
  List<OrderModel> getAllOrders() => List.from(_orders.where((o) => !o.deletedByAdmin))
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Returns only confirmed orders (placed and beyond) for admin Orders tab
  List<OrderModel> getConfirmedOrders() {
    return _orders.where((o) => o.isConfirmed).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<OrderModel> getOrdersByPainter(String painterId) {
    return _orders
        .where((o) => o.painterId == painterId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<OrderModel> getOrdersByStatus(String status) {
    if (status == 'placed') {
      return _orders.where((o) => o.status == 'placed' || o.status == 'pending_reveal').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    if (status == 'accepted') {
      return _orders.where((o) => o.status == 'accepted').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return _orders.where((o) => o.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  OrderModel? getOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── BILLING FLOW METHODS ─────────────────────────────────────

  /// Orders waiting for admin to upload bill (status == 'pending_bill')
  List<OrderModel> getOrdersForBilling() {
    return _orders.where((o) => o.status == 'pending_bill' && !o.deletedByAdmin).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where admin already sent a bill (bill_image_url is not null)
  List<OrderModel> getOrdersWithBills() {
    return _orders.where((o) => o.billImageUrl != null && o.billImageUrl!.isNotEmpty).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where admin chose "Reveal Later" (status == 'udhaari_pending_approval')
  List<OrderModel> getOrdersPendingReveal() {
    return _orders.where((o) => o.status == 'udhaari_pending_approval').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Admin marks an order as "Reveal Later" — stays in pending bills under To Be Revealed tab
  Future<void> revealLater(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(
        status: 'to_be_revealed',
        paymentMethod: 'udhaari',
        paymentStatus: 'pending',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('orders').update({
          'status': 'to_be_revealed',
          'payment_method': 'udhaari',
          'payment_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error marking reveal later: $e');
        throw Exception('Failed to mark reveal later: $e');
      }
    }
  }

  /// Orders marked as "To Be Revealed" by admin (status == 'to_be_revealed')
  List<OrderModel> getOrdersToBeRevealed() {
    return _orders.where((o) => o.status == 'to_be_revealed' && !o.deletedByAdmin).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Generate bill for a to_be_revealed order - sets amount and moves to udhaari_pending_approval
  Future<void> generateBillForRevealLater(String orderId, double totalAmount) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(
        totalAmount: totalAmount,
        status: 'udhaari_pending_approval',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('orders').update({
          'total_amount': totalAmount,
          'status': 'udhaari_pending_approval',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error generating bill for reveal later: $e');
        throw Exception('Failed to generate bill: $e');
      }
    }
  }

  /// Orders where admin has uploaded a bill OR marked as to_be_revealed — for painter's Bills tab
  List<OrderModel> getBilledOrdersForPainter(String painterId) {
    return _orders.where((o) =>
        o.painterId == painterId && 
        ((o.billImageUrl != null && o.billImageUrl!.isNotEmpty) || o.status == 'to_be_revealed' || o.status == 'udhaari_pending_approval')).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where user chose cash payment (for admin Pending Cash screen)
  List<OrderModel> getCashPendingOrders() {
    return _orders.where((o) =>
        o.paymentMethod.startsWith('cash') &&
        (o.paymentStatus == 'pending' || o.paymentStatus == 'partially_paid')).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where user chose online payment (for admin Pending Online screen)
  List<OrderModel> getOnlinePendingOrders() {
    return _orders.where((o) =>
        o.paymentMethod.startsWith('online') &&
        (o.paymentStatus == 'pending' || o.paymentStatus == 'partially_paid')).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where user chose cash and fully paid
  List<OrderModel> getCashFullyPaidOrders() {
    return _orders.where((o) =>
        o.paymentMethod.startsWith('cash') && o.paymentStatus == 'fully_paid').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Orders where user chose udhaari (for admin Udhaari requests)
  List<OrderModel> getUdhaariPendingOrders() {
    return _orders.where((o) =>
        o.paymentMethod == 'udhaari' &&
        o.status == 'payment_selected').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Place order — initial status is 'pending_bill'
  Future<OrderModel> placeOrder(OrderModel order) async {
    final newOrder = order.copyWith(
      id: _uuid.v4(),
      status: order.status.isEmpty ? 'pending_bill' : order.status,
      paymentMethod: order.paymentMethod.isEmpty ? 'udhaari' : order.paymentMethod,
      paymentStatus: order.paymentStatus.isEmpty ? 'pending' : order.paymentStatus,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    // Persist to Supabase FIRST
    try {
      await _sb.from('orders').insert(newOrder.toJson());
      _orders.add(newOrder);
      notifyListeners();
    } catch (e) {
      debugPrint('Error placing order: $e');
      rethrow;
    }

    return newOrder;
  }

  /// Admin uploads a bill image and sets total amount for an order.
  /// Moves the order to 'udhaari_pending_approval' status for admin approval in Udhaari Requests.
  Future<void> uploadBill(String orderId, String imageUrl, double totalAmount, {List<OrderItemModel>? customItems, bool hideAmount = false}) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final updatedOrder = _orders[i].copyWith(
        billImageUrl: imageUrl,
        totalAmount: totalAmount,
        items: customItems ?? _orders[i].items,
        status: 'udhaari_pending_approval', // Move to udhaari pending approval for admin to approve
        paymentMethod: 'udhaari',
        paymentStatus: 'pending',
        hideAmount: hideAmount,
        updatedAt: DateTime.now(),
      );
      
      _orders[i] = updatedOrder;
      notifyListeners();
      
      try {
        await _sb.from('orders').update({
          'bill_image_url': imageUrl,
          'total_amount': totalAmount,
          'items': (customItems ?? updatedOrder.items).map((e) => e.toJson()).toList(),
          'status': 'udhaari_pending_approval',
          'payment_method': 'udhaari',
          'payment_status': 'pending',
          'hide_amount': hideAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Note: Ledger entry and stock decrement will happen when admin approves the udhaari request

      } catch (e) {
        debugPrint('Error uploading bill: $e');
        throw Exception('Failed to upload bill: $e');
      }
    }
  }

  /// Admin approves an udhaari request and moves order to order management (status 'placed')
  Future<void> approveUdhaariRequest(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final order = _orders[i];
      _orders[i] = order.copyWith(
        status: 'placed',
        paymentStatus: 'udhaari',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      
      try {
        await _sb.from('orders').update({
          'status': 'placed',
          'payment_status': 'udhaari',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Add ledger entry for Udhaari
        await addLedgerEntry(
          painterId: order.painterId,
          type: 'credit',
          amount: order.totalAmount,
          orderId: order.id,
          note: 'Order #${order.id.substring(0, 8)} — Udhaari Approved',
          createdBy: 'system',
        );

        // Decrement stock
        for (final item in order.items) {
          final pIndex = _products.indexWhere((p) => p.id == item.productId);
          if (pIndex != -1) {
            final product = _products[pIndex];
            if (product.variantStock != null && product.variantStock!.isNotEmpty) {
              final currentVariantStock = Map<String, int>.from(product.variantStock!);
              final bucket = item.bucketSize;
              if (currentVariantStock.containsKey(bucket)) {
                currentVariantStock[bucket] = (currentVariantStock[bucket]! - item.quantity).clamp(0, 99999);
                await updateVariantStock(product.id, currentVariantStock);
              }
            } else {
              final newStock = (product.stockLevel - item.quantity).clamp(0, 99999);
              await updateStock(product.id, newStock);
            }
          }
        }

        // Auto-reward checking
        await checkAndAutoRewardGoals(order.painterId);
        await evaluateMilestonesForPainter(order.painterId);

      } catch (e) {
        debugPrint('Error approving udhaari request: $e');
        throw Exception('Failed to approve udhaari request: $e');
      }
    }
  }

  /// User requests Udhaari payment (now the only available method)
  Future<void> selectPaymentMethod(String orderId, String method) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      // We only support Udhaari now
      _orders[i] = _orders[i].copyWith(
        paymentMethod: 'udhaari',
        status: 'udhaari_requested',
        paymentStatus: 'pending',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('orders').update({
          'payment_method': 'udhaari',
          'status': 'udhaari_requested',
          'payment_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error requesting udhaari: $e');
        throw Exception('Failed to request udhaari: $e');
      }
    }
  }

  /// Admin approves an Udhaari order, uploads the final bill, and confirms the amount.
  /// Moves directly from 'pending_bill' to 'placed'.
  Future<void> approveUdhaariAndBill({
    required String orderId,
    required double totalAmount,
    required String billImageUrl,
    bool enableInterest = false,
    double interestRate = 0.0,
    double interestAmount = 0.0,
  }) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(
        totalAmount: totalAmount,
        billImageUrl: billImageUrl,
        status: 'accepted',
        paymentStatus: 'udhaari',
        paymentMethod: 'udhaari',
        udhaariInterestEnabled: enableInterest,
        udhaariInterestRate: interestRate,
        udhaariInterestAmount: interestAmount,
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      try {
        await _sb.from('orders').update({
          'total_amount': totalAmount,
          'bill_image_url': billImageUrl,
          'status': 'accepted',
          'payment_status': 'udhaari',
          'payment_method': 'udhaari',
          'udhaari_interest_enabled': enableInterest,
          'udhaari_interest_rate': interestRate,
          'udhaari_interest_amount': interestAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Ledger entry for Udhaari with total including interest
        final order = _orders[i];
        final totalWithInterest = order.totalAmount + interestAmount;
        await addLedgerEntry(
          painterId: order.painterId,
          type: 'credit',
          amount: totalWithInterest,
          orderId: order.id,
          note: 'Order #${order.id.substring(0, 8)} — Udhaari (Finalized)',
          createdBy: 'system',
        );
      } catch (e) {
        debugPrint('Error approving udhaari: $e');
        throw Exception('Failed to approve udhaari: $e');
      }
    }
  }

  /// Admin confirms and places the final order (moves to fulfillment)
  Future<void> confirmFinalOrder(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      if (_orders[i].paymentStatus == 'pending') {
        throw Exception('Cannot accept order until payment is verified/set.');
      }
      _orders[i] = _orders[i].copyWith(
        status: 'placed',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      try {
        await _sb.from('orders').update({
          'status': 'placed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error confirming order: $e');
        throw Exception('Failed to confirm order: $e');
      }
    }
  }

  /// Admin verifies a cash or online payment
  Future<void> verifyPayment({
    required String orderId,
    required double amountReceived,
    required String method,
    required bool isFull,
    required String adminId,
    String? referenceId,
  }) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final newPaid = _orders[i].paidAmount + amountReceived;
      final paymentStatus = isFull ? 'fully_paid' : 'partially_paid';
      
      final currentStatus = _orders[i].status;
      final newStatus = (currentStatus == 'payment_selected' || currentStatus == 'udhaari_requested') ? 'placed' : currentStatus;

      _orders[i] = _orders[i].copyWith(
        paidAmount: newPaid,
        paymentStatus: paymentStatus,
        paymentMethod: method, // ensuring it's updated in case they switched
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      
      try {
        // 1. Log to payments table
        await _sb.from('payments').insert({
          'id': DateTime.now().millisecondsSinceEpoch.toString() + orderId.substring(0, 4),
          'order_id': orderId,
          'payment_method': method,
          'amount': amountReceived,
          'reference_id': referenceId,
          'created_by': adminId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 2. Update order
        await _sb.from('orders').update({
          'paid_amount': newPaid,
          'payment_status': paymentStatus,
          'payment_method': method,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error verifying payment: $e');
        throw Exception('Failed to verify payment: $e');
      }
    }
  }

  /// Processes an Udhaari order, optionally adding interest
  Future<void> markUdhaari({
    required String orderId,
    required bool enableInterest,
    required double interestRate,
    required double interestAmount,
  }) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final currentStatus = _orders[i].status;
      final newStatus = (currentStatus == 'payment_selected' || currentStatus == 'udhaari_requested') ? 'placed' : currentStatus;

      _orders[i] = _orders[i].copyWith(
        paymentStatus: 'udhaari',
        status: newStatus,
        udhaariInterestEnabled: enableInterest,
        udhaariInterestRate: interestRate,
        udhaariInterestAmount: interestAmount,
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      try {
        await _sb.from('orders').update({
          'payment_status': 'udhaari',
          'status': newStatus,
          'udhaari_interest_enabled': enableInterest,
          'udhaari_interest_rate': interestRate,
          'udhaari_interest_amount': interestAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Ledger entry for Udhaari with total including interest
        final order = _orders[i];
        final totalWithInterest = order.totalAmount + interestAmount;
        await addLedgerEntry(
          painterId: order.painterId,
          type: 'credit',
          amount: totalWithInterest,
          orderId: order.id,
          note: 'Order #${order.id.substring(0, 8)} — Udhaari Payment (${enableInterest ? "Includes $interestRate% interest" : "No interest"})',
          createdBy: 'system',
        );
      } catch (e) {
        debugPrint('Error marking udhaari: $e');
        throw Exception('Failed to mark udhaari: $e');
      }
    }
  }

  /// Marks an active udhaari as completed (painter has paid)
  Future<void> markUdhaariCompleted(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(
        paymentStatus: 'udhaari_completed',
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      try {
        await _sb.from('orders').update({
          'payment_status': 'udhaari_completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Add debit ledger entry to settle the udhaari
        final order = _orders[i];
        final totalWithInterest = order.totalAmount + order.udhaariInterestAmount;
        await addLedgerEntry(
          painterId: order.painterId,
          type: 'debit',
          amount: totalWithInterest,
          orderId: order.id,
          note: 'Order #${order.id.substring(0, 8)} — Udhaari Paid (Settled)',
          createdBy: 'admin',
        );
      } catch (e) {
        debugPrint('Error marking udhaari completed: $e');
        throw Exception('Failed to mark udhaari completed: $e');
      }
    }
  }

  /// Marks a cancelled order's refund as completed
  Future<void> processRefund(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      if (_orders[i].status != 'cancelled') {
        throw Exception('Order must be cancelled before a refund can be processed.');
      }
      if (_orders[i].paidAmount <= 0) {
        throw Exception('No payment was made, so no refund is necessary.');
      }

      _orders[i] = _orders[i].copyWith(
        refundCompleted: true,
        paymentStatus: 'refunded',
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      try {
        await _sb.from('orders').update({
          'refund_completed': true,
          'payment_status': 'refunded',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error processing refund: $e');
        throw Exception('Failed to process refund: $e');
      }
    }
  }

  /// Upload bill image to Supabase Storage and return URL
  Future<String> uploadBillImage(String orderId, dynamic imageBytes, String fileName) async {
    try {
      final path = 'bills/$orderId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      final url = _sb.storage.from('paint-images').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading bill image: $e');
      throw Exception('Failed to upload bill image: $e');
    }
  }

  /// Upload bill PDF to Supabase Storage and return URL
  Future<String> uploadBillPdf(String orderId, dynamic pdfBytes, String fileName) async {
    try {
      final path = 'bills/$orderId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        pdfBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
      );
      final url = _sb.storage.from('paint-images').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading bill PDF: $e');
      throw Exception('Failed to upload bill PDF: $e');
    }
  }

  /// Upload product image to Supabase Storage and return URL
  Future<String> uploadProductImage(String productId, dynamic imageBytes, String fileName) async {
    try {
      final path = 'products/$productId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      final url = _sb.storage.from('paint-images').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      throw Exception('Failed to upload product image: $e');
    }
  }

  /// Uploads a user's profile selfie to storage and returns its public URL.
  Future<String> uploadProfileImage(String userId, dynamic imageBytes, String fileName) async {
    try {
      final path = 'profiles/$userId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _sb.storage.from('paint-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Persists a user's profile image URL and refreshes the in-memory cache.
  Future<void> updateUserProfileImage(String userId, String url) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(profileImageUrl: url);
      notifyListeners();
    }
    try {
      await _sb.from('users').update({'profile_image_url': url}).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      throw Exception('Failed to update profile image: $e');
    }
  }

  // ─── BANK DETAILS ────────────────────────────────────────────

  /// Uploads a passbook image to Supabase Storage and returns its public URL.
  Future<String> uploadBankPassbook(
      String userId, dynamic imageBytes, String fileName) async {
    try {
      final path = 'bank-passbooks/$userId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _sb.storage.from('paint-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading bank passbook: $e');
      throw Exception('Failed to upload passbook: $e');
    }
  }

  /// Saves bank details and sets bankStatus → 'pending'.
  Future<void> updateUserBankDetails(
      String userId, String accountNumber, String passbookUrl) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        bankAccountNumber: accountNumber,
        bankPassbookUrl: passbookUrl,
        bankStatus: 'pending',
        bankRejectionSeen: false,
      );
      notifyListeners();
    }
    try {
      await _sb.from('users').update({
        'bank_account_number': accountNumber,
        'bank_passbook_url': passbookUrl,
        'bank_status': 'pending',
        'bank_rejection_seen': false,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating bank details: $e');
      throw Exception('Failed to update bank details: $e');
    }
  }

  /// Sets bankStatus to 'approved' or 'rejected'.
  /// On rejection also resets bankRejectionSeen so the gate fires next open.
  Future<void> updateBankStatus(String userId, String status) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        bankStatus: status,
        bankRejectionSeen: status == 'rejected' ? false : null,
      );
      notifyListeners();
    }
    try {
      final payload = <String, dynamic>{'bank_status': status};
      if (status == 'rejected') payload['bank_rejection_seen'] = false;
      await _sb.from('users').update(payload).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating bank status: $e');
      throw Exception('Failed to update bank status: $e');
    }
  }

  /// Called after painter sees the rejection screen — prevents the gate firing again.
  Future<void> markBankRejectionSeen(String userId) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(bankRejectionSeen: true);
      notifyListeners();
    }
    try {
      await _sb
          .from('users')
          .update({'bank_rejection_seen': true}).eq('id', userId);
    } catch (e) {
      debugPrint('Error marking rejection seen: $e');
    }
  }

  // ─── BRANDS ──────────────────────────────────────────────────

  /// All brands sorted by sort_order then name. Falls back to deriving
  /// brand names from products if the brands table is empty (pre-migration).
  List<BrandModel> getAllBrands() {
    if (_brands.isNotEmpty) {
      final sorted = List<BrandModel>.from(_brands)
        ..sort((a, b) {
          final cmp = a.sortOrder.compareTo(b.sortOrder);
          return cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return sorted;
    }
    // Fallback: derive unique brand names from products.
    final names = _products.map((p) => p.brand).toSet().toList()..sort();
    return names.map((n) => BrandModel(id: n, name: n, createdAt: DateTime.now())).toList();
  }

  BrandModel? getBrandByName(String name) {
    final normalized = _normalizeLabel(name);
    try {
      return _brands.firstWhere((b) => _normalizeLabel(b.name) == normalized);
    } catch (_) {
      return null;
    }
  }

  Future<BrandModel> addBrand({required String name, String? logoUrl}) async {
    final maxOrder = _brands.isEmpty ? 0 : _brands.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b);
    final brand = BrandModel(
      id: _uuid.v4(),
      name: name,
      logoUrl: logoUrl,
      sortOrder: maxOrder + 1,
      createdAt: DateTime.now(),
    );
    _brands.add(brand);
    notifyListeners();
    try {
      await _sb.from('brands').insert(brand.toJson());
    } catch (e) {
      debugPrint('Error adding brand: $e');
      _brands.removeLast();
      notifyListeners();
      throw Exception('Failed to add brand: $e');
    }
    return brand;
  }

  Future<String> uploadBrandLogo(String brandId, dynamic imageBytes, String fileName) async {
    try {
      final path = 'brands/$brandId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _sb.storage.from('paint-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading brand logo: $e');
      throw Exception('Failed to upload brand logo: $e');
    }
  }

  Future<void> updateBrandLogo(String brandId, String url) async {
    final i = _brands.indexWhere((b) => b.id == brandId);
    if (i != -1) {
      _brands[i] = _brands[i].copyWith(logoUrl: url);
      notifyListeners();
    }
    try {
      await _sb.from('brands').update({'logo_url': url}).eq('id', brandId);
    } catch (e) {
      debugPrint('Error updating brand logo: $e');
      throw Exception('Failed to update brand logo: $e');
    }
  }

  /// Update brand name
  Future<void> updateBrandName(String brandId, String newName) async {
    final i = _brands.indexWhere((b) => b.id == brandId);
    if (i != -1) {
      _brands[i] = _brands[i].copyWith(name: newName);
      notifyListeners();
    }
    try {
      await _sb.from('brands').update({'name': newName}).eq('id', brandId);
    } catch (e) {
      debugPrint('Error updating brand name: $e');
      throw Exception('Failed to update brand name: $e');
    }
  }

  // ─── BANNERS / PAMPHLETS ────────────────────────────────────

  List<BannerModel> getActiveBanners() {
    return _banners.where((b) => b.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<BannerModel> getAllBanners() => List.unmodifiable(_banners);

  Future<String> uploadBannerImage(String bannerId, dynamic bytes, String fileName) async {
    try {
      final path = 'banners/$bannerId/$fileName';
      await _sb.storage.from('paint-images').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _sb.storage.from('paint-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading banner: $e');
      throw Exception('Failed to upload banner: $e');
    }
  }

  Future<BannerModel> addBanner({required String imageUrl, String? title}) async {
    final maxOrder = _banners.isEmpty ? 0 : _banners.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b);
    final banner = BannerModel(
      id: _uuid.v4(),
      imageUrl: imageUrl,
      title: title,
      sortOrder: maxOrder + 1,
      createdAt: DateTime.now(),
    );
    _banners.add(banner);
    notifyListeners();
    try {
      await _sb.from('banners').insert(banner.toJson());
    } catch (e) {
      debugPrint('Error adding banner: $e');
      _banners.removeLast();
      notifyListeners();
      throw Exception('Failed to add banner: $e');
    }
    return banner;
  }

  Future<void> deleteBanner(String id) async {
    _banners.removeWhere((b) => b.id == id);
    notifyListeners();
    try {
      await _sb.from('banners').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting banner: $e');
    }
  }

  Future<void> toggleBannerActive(String id, bool active) async {
    final i = _banners.indexWhere((b) => b.id == id);
    if (i == -1) return;
    _banners[i] = BannerModel(
      id: _banners[i].id,
      imageUrl: _banners[i].imageUrl,
      title: _banners[i].title,
      isActive: active,
      sortOrder: _banners[i].sortOrder,
      createdAt: _banners[i].createdAt,
    );
    notifyListeners();
    try {
      await _sb.from('banners').update({'is_active': active}).eq('id', id);
    } catch (e) {
      debugPrint('Error toggling banner: $e');
    }
  }

  /// Deletes the brand, its products, and its persisted categories.
  Future<void> deleteBrand(String brandId) async {
    final brand = _brands.firstWhere((b) => b.id == brandId, orElse: () => throw Exception('Brand not found'));
    final brandName = brand.name;
    // Collect product IDs to delete.
    final productIds = _products.where((p) => _normalizeLabel(p.brand) == _normalizeLabel(brandName)).map((p) => p.id).toList();
    // Remove in-memory.
    _products.removeWhere((p) => _normalizeLabel(p.brand) == _normalizeLabel(brandName));
    _brandCategories.removeWhere((c) => _normalizeLabel(c['brand'] as String) == _normalizeLabel(brandName));
    _brands.removeWhere((b) => b.id == brandId);
    notifyListeners();
    // Persist deletions.
    try {
      if (productIds.isNotEmpty) {
        await _sb.from('products').delete().inFilter('id', productIds);
      }
      await _sb.from('brand_categories').delete().eq('brand', brandName);
      await _sb.from('brands').delete().eq('id', brandId);
    } catch (e) {
      debugPrint('Error deleting brand: $e');
      // Re-fetch to recover consistent state.
      await refresh();
      throw Exception('Failed to delete brand: $e');
    }
  }

  /// Ensures a brand row exists for the given name (called on product add).
  Future<void> ensureBrandExists(String name) async {
    if (name.isEmpty) return;
    if (getBrandByName(name) != null) return;
    await addBrand(name: name);
  }

  // ─── BRAND CATEGORIES ────────────────────────────────────────

  /// Categories persisted in brand_categories for [brand].
  List<String> getPersistedCategories(String brand) {
    final normalized = _normalizeLabel(brand);
    return _brandCategories
        .where((c) => _normalizeLabel(c['brand'] as String) == normalized)
        .map((c) => c['name'] as String)
        .toList();
  }

  /// Union of derived (from products) + persisted categories for [brand].
  List<String> getAllCategoriesForBrand(String brand) {
    final derived = getCategoriesForBrand(brand);
    final persisted = getPersistedCategories(brand);
    final union = {...derived, ...persisted}.where((c) => c.isNotEmpty && c != 'None').toList();
    union.sort();
    return union;
  }

  Future<void> addBrandCategory(String brand, String name) async {
    final existing = getAllCategoriesForBrand(brand);
    if (existing.map(_normalizeLabel).contains(_normalizeLabel(name))) return;
    final entry = {
      'id': _uuid.v4(),
      'brand': brand,
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    };
    _brandCategories.add(entry);
    notifyListeners();
    try {
      await _sb.from('brand_categories').insert(entry);
    } catch (e) {
      debugPrint('Error adding brand category: $e');
      _brandCategories.removeLast();
      notifyListeners();
      throw Exception('Failed to add brand category: $e');
    }
  }

  Future<void> deleteBrandCategory(String id) async {
    _brandCategories.removeWhere((c) => c['id'] == id);
    notifyListeners();
    try {
      await _sb.from('brand_categories').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting brand category: $e');
    }
  }

  Map<String, String> getPersistedCategoryIds(String brand) {
    final normalized = _normalizeLabel(brand);
    final result = <String, String>{};
    for (final c in _brandCategories) {
      if (_normalizeLabel(c['brand'] as String) == normalized) {
        result[c['name'] as String] = c['id'] as String;
      }
    }
    return result;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final oldStatus = _orders[i].status;
      final order = _orders[i];
      _orders[i] = _orders[i].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      
      try {
        await _sb.from('orders').update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);

        // Decrement stock if transitioning to 'delivered'
        if (status == 'delivered' && oldStatus != 'delivered') {
          for (final item in order.items) {
            final pIndex = _products.indexWhere((p) => p.id == item.productId);
            if (pIndex != -1) {
              final product = _products[pIndex];
              if (product.variantStock != null && product.variantStock!.isNotEmpty) {
                final currentVariantStock = Map<String, int>.from(product.variantStock!);
                final bucket = item.bucketSize;
                if (currentVariantStock.containsKey(bucket)) {
                  currentVariantStock[bucket] = (currentVariantStock[bucket]! - item.quantity).clamp(0, 99999);
                  await updateVariantStock(product.id, currentVariantStock);
                }
              } else {
                final newStock = (product.stockLevel - item.quantity).clamp(0, 99999);
                await updateStock(product.id, newStock);
              }
            }
          }

          // Auto-reward checking
          await checkAndAutoRewardGoals(order.painterId);
          await evaluateMilestonesForPainter(order.painterId);
        }
      } catch (e) {
        debugPrint('Error updating order status: $e');
        throw Exception('Failed to update order status: $e');
      }
    }
  }

  Future<void> generateBill(String orderId, double amount) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(
        totalAmount: amount,
        status: 'billed',
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return _sb.from('orders').update({
        'total_amount': amount,
        'status': 'billed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId).catchError((e) {
        debugPrint('Error generating bill: $e');
        throw Exception('Failed to generate bill: $e');
      });
    }
  }

  Future<void> completePayment(String orderId, String method) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      final order = _orders[i];
      _orders[i] = order.copyWith(
        status: 'paid',
        paymentMethod: method,
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      await _sb.from('orders').update({
        'status': 'paid',
        'payment_method': method,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Ledger entry for Udhaari
      if (method == 'udhaari') {
        await addLedgerEntry(
          painterId: order.painterId,
          type: 'credit',
          amount: order.totalAmount,
          orderId: order.id,
          note: 'Order #${order.id.substring(0, 8)} — Udhaari Payment',
          createdBy: 'system',
        );
      }
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      // 1. Mark as deleted in memory
      _orders[i] = _orders[i].copyWith(deletedByAdmin: true, status: 'deleted');
      
      // 2. Remove associated ledger entries from in-memory cache
      _ledger.removeWhere((e) => e.orderId == orderId);
      
      notifyListeners();

      try {
        // 3. Soft delete in Supabase - mark as deleted and clear bill
        await _sb.from('orders').update({
          'deleted_by_admin': true,
          'status': 'deleted',
          'bill_image_url': null,
        }).eq('id', orderId);
        
        // 4. Delete from Supabase ledger table (if any)
        await _sb.from('ledger').delete().eq('order_id', orderId);
      } catch (e) {
        debugPrint('Error deleting order or related ledger entries: $e');
        throw Exception('Failed to delete order: $e');
      }
    }
  }

  Future<void> bulkDeleteOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return;

    // 1. Mark as deleted in memory
    for (final id in orderIds) {
      final i = _orders.indexWhere((o) => o.id == id);
      if (i != -1) {
        _orders[i] = _orders[i].copyWith(deletedByAdmin: true, status: 'deleted');
      }
      _ledger.removeWhere((e) => e.orderId == id);
    }
    notifyListeners();

    try {
      // 2. Soft delete in Supabase
      await _sb.from('orders').update({
        'deleted_by_admin': true,
        'status': 'deleted',
        'bill_image_url': null,
      }).inFilter('id', orderIds);
      await _sb.from('ledger').delete().inFilter('order_id', orderIds);
    } catch (e) {
      debugPrint('Error bulk deleting orders: $e');
      throw Exception('Failed to bulk delete orders: $e');
    }
  }

  // ─── COMMISSION ────────────────────────────────────────────────

  /// Update the commission for an order (admin-only). Persists to Supabase.
  Future<void> updateOrderCommission(String orderId, double commission) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) {
      _orders[i] = _orders[i].copyWith(commission: commission);
      notifyListeners();
      try {
        await _sb.from('orders').update({
          'commission': commission,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } catch (e) {
        debugPrint('Error updating commission: $e');
        rethrow;
      }
    }
  }

  // ─── POINTS MANAGEMENT ─────────────────────────────────────────

  /// Set a painter's points to [points] and persist. Negative values are clamped to 0.
  Future<void> updateUserPoints(String userId, int points) async {
    final clamped = points < 0 ? 0 : points;
    final i = _users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      _users[i] = _users[i].copyWith(points: clamped);
      notifyListeners();
      try {
        await _sb.from('users').update({
          'points': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (e) {
        debugPrint('Error updating user points: $e');
        rethrow;
      }
    }
  }

  // ─── GOALS ─────────────────────────────────────────────────────
  List<GoalModel> getAllGoals() => _goals;

  GoalModel? getGoalById(String id) {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  List<GoalModel> getGoalsByBrand(String brand) {
    return _goals.where((g) => g.brand.toLowerCase() == brand.toLowerCase()).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
  }

  List<GoalModel> getGoalsForPainter(String painterId) {
    return _goals.where((g) {
      return g.isActive &&
          (g.assignedTo.contains('all') ||
              g.assignedTo.contains(painterId));
    }).toList();
  }

  int getPainterProgressForGoal(String painterId, GoalModel goal) {
    final painterOrders = _orders.where((o) =>
        o.painterId == painterId &&
        o.brand == goal.brand &&
        o.status == 'delivered' &&
        o.createdAt.isAfter(goal.startDate) &&
        o.createdAt.isBefore(goal.endDate));
    int totalQty = 0;
    for (final order in painterOrders) {
      for (final item in order.items) {
        totalQty += item.quantity;
      }
    }
    return totalQty;
  }

  Future<void> addGoal(GoalModel goal) async {
    _goals.add(goal);
    notifyListeners();
    return _sb.from('goals').insert(goal.toJson()).catchError((e) {
      debugPrint('Error adding goal: $e');
      throw Exception('Failed to add goal: $e');
    });
  }

  Future<void> updateGoal(GoalModel goal) async {
    final i = _goals.indexWhere((g) => g.id == goal.id);
    if (i != -1) {
      _goals[i] = goal;
      notifyListeners();
      return _sb.from('goals').update(goal.toJson()).eq('id', goal.id).catchError((e) {
        debugPrint('Error updating goal: $e');
        throw Exception('Failed to update goal: $e');
      });
    }
  }

  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
    return _sb.from('goals').delete().eq('id', goalId).catchError((e) {
      debugPrint('Error deleting goal: $e');
      throw Exception('Failed to delete goal: $e');
    });
  }

  // ─── REWARDS ───────────────────────────────────────────────────
  List<RewardModel> getRewardsForPainter(String painterId) {
    return _rewards.where((r) => r.painterId == painterId).toList()
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
  }

  Future<void> addReward(RewardModel reward) async {
    _rewards.add(reward);
    notifyListeners();
    return _sb.from('rewards').insert(reward.toJson()).catchError((e) {
      debugPrint('Error adding reward: $e');
      throw Exception('Failed to add reward: $e');
    });
  }

  Future<void> deleteReward(String rewardId) async {
    _rewards.removeWhere((r) => r.id == rewardId);
    notifyListeners();
    return _sb.from('rewards').delete().eq('id', rewardId).catchError((e) {
      debugPrint('Error deleting reward: $e');
      throw Exception('Failed to delete reward: $e');
    });
  }

  /// Check if a painter has already claimed a goal reward
  bool hasClaimedGoal(String painterId, String goalId) {
    return _rewards.any((r) => r.painterId == painterId && r.goalId == goalId);
  }

  /// Claim a goal reward — creates a reward entry and persists
  Future<void> claimGoalReward(String painterId, GoalModel goal) async {
    if (hasClaimedGoal(painterId, goal.id)) return;
    final reward = RewardModel(
      id: _uuid.v4(),
      painterId: painterId,
      goalId: goal.id,
      rewardAmount: goal.rewardAmount,
      status: 'earned',
      earnedAt: DateTime.now(),
    );
    _rewards.add(reward);

    // Auto-credit points if the reward type is points
    if (goal.rewardType.toLowerCase() == 'points') {
      final user = getUserById(painterId);
      if (user != null) {
        final newPoints = user.points + goal.rewardAmount.toInt();
        final userIdx = _users.indexWhere((u) => u.id == painterId);
        if (userIdx != -1) {
          _users[userIdx] = _users[userIdx].copyWith(points: newPoints);
        }
        try {
          await _sb.from('users').update({
            'points': newPoints,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', painterId);
        } catch (e) {
          debugPrint('Error updating user points: $e');
        }
      }
    }

    notifyListeners();
    try {
      await _sb.from('rewards').insert(reward.toJson());
    } catch (e) {
      debugPrint('Error claiming reward: $e');
      throw Exception('Failed to claim reward: $e');
    }
  }

  /// Automatically check all active goals for a painter. If completed and not claimed, claim them!
  Future<void> checkAndAutoRewardGoals(String painterId) async {
    final activeGoals = getGoalsForPainter(painterId);
    for (final goal in activeGoals) {
      if (!hasClaimedGoal(painterId, goal.id)) {
        final progress = getPainterProgressForGoal(painterId, goal);
        if (progress >= goal.targetQuantity) {
          await claimGoalReward(painterId, goal);
          NotificationService.showGoalAchieved(
            goalTitle: goal.brand,
            rewardAmount: goal.rewardAmount,
          );
        }
      }
    }
  }

  // ─── STATS ─────────────────────────────────────────────────────
  double getTotalRevenue() {
    return _orders
        .where((o) => o.paymentStatus == 'fully_paid' || o.paymentStatus == 'partially_paid' || o.paymentStatus == 'udhaari')
        .fold(0, (sum, o) => sum + o.totalAmount);
  }

  int getTotalOrdersCount() => _orders.length;

  int getActivePaintersCount() =>
      _users.where((u) => u.role == 'painter' && u.status == 'active').length;

  int getPendingApprovalsCount() =>
      _users
          .where((u) => u.role == 'painter' && u.status == 'inactive')
          .length;

  double getPainterLifetimeValue(String painterId) {
    return _orders
        .where((o) => o.painterId == painterId && o.status == 'delivered')
        .fold(0, (sum, o) => sum + o.totalAmount);
  }

  Map<String, int> getPainterBrandBreakdown(String painterId) {
    final result = <String, int>{};
    for (final order in _orders.where((o) => o.painterId == painterId)) {
      for (final item in order.items) {
        result[order.brand] = (result[order.brand] ?? 0) + item.quantity;
      }
    }
    return result;
  }

  // ─── ENHANCED DASHBOARD STATS ─────────────────────────────────
  int getTotalBucketsForPainter(String painterId) {
    int total = 0;
    for (final order in _orders.where((o) => o.painterId == painterId && o.status == 'delivered')) {
      for (final item in order.items) {
        total += item.quantity;
      }
    }
    return total;
  }

  int getPendingOrdersCountForPainter(String painterId) {
    return _orders
        .where((o) =>
            o.painterId == painterId &&
            (o.status == 'placed' || o.status == 'accepted' || o.status == 'preparing'))
        .length;
  }

  double getRewardPointsForPainter(String painterId) {
    return _rewards
        .where((r) => r.painterId == painterId)
        .fold(0.0, (sum, r) => sum + r.rewardAmount);
  }

  /// Returns last N unique products ordered by painter for quick reorder
  List<Map<String, dynamic>> getLastOrderedProducts(String painterId, {int limit = 3}) {
    final painterOrders = _orders
        .where((o) => o.painterId == painterId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final order in painterOrders) {
      for (final item in order.items) {
        if (!seen.contains(item.productId)) {
          seen.add(item.productId);
          result.add({
            'id': item.productId, // Match UI expectation
            'productId': item.productId,
            'productName': item.productName,
            'colorCode': item.colorCode,
            'colorHex': item.colorHex,
            'bucketSize': item.bucketSize,
            'quantity': item.quantity,
            'brand': order.brand,
            'imageUrl': item.productImageUrl, // Use persisted image
          });
          if (result.length >= limit) return result;
        }
      }
    }
    return result;
  }

  // ─── ADMIN ANALYTICS ──────────────────────────────────────────
  double getDailyRevenue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _orders
        .where((o) => o.createdAt.isAfter(today) && (o.paymentStatus == 'fully_paid' || o.paymentStatus == 'partially_paid' || o.paymentStatus == 'udhaari'))
        .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  int getTodayOrdersCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _orders.where((o) => o.createdAt.isAfter(today)).length;
  }

  /// Returns top painter by total order value
  Map<String, dynamic>? getTopPainter() {
    if (_orders.isEmpty) return null;
    final spendMap = <String, double>{};
    for (final o in _orders) {
      spendMap[o.painterId] = (spendMap[o.painterId] ?? 0) + o.totalAmount;
    }
    if (spendMap.isEmpty) return null;
    final topId = spendMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final painter = getUserById(topId);
    return {'name': painter?.name ?? 'Unknown', 'amount': spendMap[topId]};
  }

  /// Returns top product by order quantity
  Map<String, dynamic>? getTopProduct() {
    if (_orders.isEmpty) return null;
    final qtyMap = <String, int>{};
    final nameMap = <String, String>{};
    for (final o in _orders) {
      for (final item in o.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
        nameMap[item.productId] = item.productName;
      }
    }
    final topId = qtyMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return {'name': nameMap[topId], 'quantity': qtyMap[topId]};
  }

  /// Returns top painters ranked by total spend
  List<Map<String, dynamic>> getPainterLeaderboard({int limit = 5}) {
    final spendMap = <String, double>{};
    for (final o in _orders) {
      spendMap[o.painterId] = (spendMap[o.painterId] ?? 0) + o.totalAmount;
    }
    final sorted = spendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      final painter = getUserById(e.key);
      return {
        'painterId': e.key,
        'name': painter?.name ?? 'Unknown',
        'totalSpend': e.value,
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // ADVANCED ALGORITHMS
  // ═══════════════════════════════════════════════════════════════

  // ─── DEMAND FORECASTING (4-week Moving Average) ───────────────
  /// Returns predicted demand for each product (next 30 days).
  /// Uses a 4-week Simple Moving Average on order quantities.
  List<Map<String, dynamic>> getDemandForecast() {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));

    // Aggregate qty per product per week (4 weeks)
    final weeklyQty = <String, List<int>>{}; // productId -> [w1, w2, w3, w4]
    final nameMap = <String, String>{};
    final brandMap = <String, String>{};
    final imageMap = <String, String?>{};

    for (final product in _products) {
      weeklyQty[product.id] = [0, 0, 0, 0];
      nameMap[product.id] = product.name;
      brandMap[product.id] = product.brand;
      imageMap[product.id] = product.imageUrl;
    }

    for (final order in _orders) {
      if (order.createdAt.isBefore(fourWeeksAgo)) continue;
      final weekIndex = ((now.difference(order.createdAt).inDays) / 7).floor();
      if (weekIndex < 0 || weekIndex > 3) continue;
      final wi = 3 - weekIndex; // 0=oldest, 3=most recent
      for (final item in order.items) {
        if (weeklyQty.containsKey(item.productId)) {
          weeklyQty[item.productId]![wi] += item.quantity;
        }
      }
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in weeklyQty.entries) {
      final weeks = entry.value;
      final avg = weeks.reduce((a, b) => a + b) / 4.0;
      final predicted = (avg * 4.3).round(); // ~30 days
      if (predicted > 0 || weeks.any((w) => w > 0)) {
        // Exponential smoothing weight (alpha=0.3)
        double ema = weeks[0].toDouble();
        for (int i = 1; i < 4; i++) {
          ema = 0.3 * weeks[i] + 0.7 * ema;
        }
        final emaPredicted = (ema * 4.3).round();

        results.add({
          'productId': entry.key,
          'productName': nameMap[entry.key] ?? '',
          'brand': brandMap[entry.key] ?? '',
          'productImageUrl': imageMap[entry.key] ?? '',
          'weeklyData': weeks,
          'movingAvgPrediction': predicted,
          'emaPrediction': emaPredicted,
          'trend': weeks[3] > weeks[0] ? 'rising' : (weeks[3] < weeks[0] ? 'falling' : 'stable'),
        });
      }
    }
    results.sort((a, b) => (b['emaPrediction'] as int).compareTo(a['emaPrediction'] as int));
    return results;
  }

  // ─── PRODUCT RECOMMENDATION ENGINE ────────────────────────────
  /// Recommends products for a painter based on collaborative filtering.
  /// Finds painters with similar purchase patterns and suggests items
  /// those painters bought that this painter hasn't.
  List<ProductModel> getRecommendedProducts(String painterId, {int limit = 6}) {
    // Step 1: Get this painter's purchased product IDs
    final myProductIds = <String>{};
    for (final order in _orders.where((o) => o.painterId == painterId)) {
      for (final item in order.items) {
        myProductIds.add(item.productId);
      }
    }
    if (myProductIds.isEmpty) {
      // Cold start: return popular products
      return _getPopularProducts(limit);
    }

    // Step 2: Find similar painters (those who bought ≥2 of the same products)
    final painterProducts = <String, Set<String>>{}; // painterId -> productIds
    for (final order in _orders) {
      if (order.painterId == painterId) continue;
      painterProducts.putIfAbsent(order.painterId, () => {});
      for (final item in order.items) {
        painterProducts[order.painterId]!.add(item.productId);
      }
    }

    // Calculate Jaccard similarity
    final similarities = <String, double>{};
    for (final entry in painterProducts.entries) {
      final intersection = myProductIds.intersection(entry.value).length;
      if (intersection < 1) continue;
      final union = myProductIds.union(entry.value).length;
      similarities[entry.key] = intersection / union;
    }

    // Step 3: Get products from top similar painters that I haven't bought
    final candidateScores = <String, double>{};
    for (final entry in similarities.entries) {
      final theirProducts = painterProducts[entry.key]!;
      for (final pid in theirProducts) {
        if (!myProductIds.contains(pid)) {
          candidateScores[pid] = (candidateScores[pid] ?? 0) + entry.value;
        }
      }
    }

    // Step 4: Sort by score and return top N
    final sortedCandidates = candidateScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recommended = <ProductModel>[];
    for (final c in sortedCandidates.take(limit)) {
      final product = _products.where((p) => p.id == c.key).firstOrNull;
      if (product != null) recommended.add(product);
    }

    // Fill remaining slots with popular products
    if (recommended.length < limit) {
      final popular = _getPopularProducts(limit - recommended.length);
      for (final p in popular) {
        if (!recommended.any((r) => r.id == p.id) && !myProductIds.contains(p.id)) {
          recommended.add(p);
        }
      }
    }
    return recommended.take(limit).toList();
  }

  List<ProductModel> _getPopularProducts(int limit) {
    final qtyMap = <String, int>{};
    for (final o in _orders) {
      for (final item in o.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
      }
    }
    final sorted = qtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      // Use where(...).firstOrNull to avoid "No element" error if a product was deleted
      return _products.where((p) => p.id == e.key).firstOrNull;
    }).whereType<ProductModel>().toList();
  }

  // ─── DYNAMIC REWARD TIERING ALGORITHM ─────────────────────────
  /// Calculates dynamic reward points based on purchase consistency,
  /// volume, and recency. Returns a map with breakdown.
  Map<String, dynamic> calculateDynamicRewardPoints(String painterId) {
    final painterOrders = _orders
        .where((o) => o.painterId == painterId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (painterOrders.isEmpty) {
      return {
        'totalPoints': 0.0,
        'volumePoints': 0.0,
        'consistencyPoints': 0.0,
        'recencyPoints': 0.0,
        'tier': 'bronze',
        'nextTier': 'silver',
        'pointsToNextTier': 500.0,
      };
    }

    // Volume Score: ₹1 spent = 0.5 points
    final totalSpent = painterOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final volumePoints = totalSpent * 0.5;

    // Consistency Score: reward regular ordering patterns
    // Check how many distinct weeks had orders in last 90 days
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final recentOrders = painterOrders.where((o) => o.createdAt.isAfter(ninetyDaysAgo));
    final activeWeeks = <int>{};
    for (final o in recentOrders) {
      activeWeeks.add(o.createdAt.difference(ninetyDaysAgo).inDays ~/ 7);
    }
    final consistencyRatio = activeWeeks.length / 13.0; // 13 weeks in 90 days
    final consistencyPoints = consistencyRatio * 200; // max 200 points

    // Recency Score: more recent orders = more points
    final lastOrderDaysAgo = now.difference(painterOrders.last.createdAt).inDays;
    double recencyPoints;
    if (lastOrderDaysAgo <= 7) {
      recencyPoints = 100;
    } else if (lastOrderDaysAgo <= 14) {
      recencyPoints = 75;
    } else if (lastOrderDaysAgo <= 30) {
      recencyPoints = 50;
    } else {
      recencyPoints = 10;
    }

    final totalPoints = volumePoints + consistencyPoints + recencyPoints;

    // Dynamic tier calculation
    String tier;
    String nextTier;
    double pointsToNextTier;
    if (totalPoints >= 5000) {
      tier = 'platinum';
      nextTier = 'platinum';
      pointsToNextTier = 0;
    } else if (totalPoints >= 2000) {
      tier = 'gold';
      nextTier = 'platinum';
      pointsToNextTier = 5000 - totalPoints;
    } else if (totalPoints >= 500) {
      tier = 'silver';
      nextTier = 'gold';
      pointsToNextTier = 2000 - totalPoints;
    } else {
      tier = 'bronze';
      nextTier = 'silver';
      pointsToNextTier = 500 - totalPoints;
    }

    return {
      'totalPoints': totalPoints,
      'volumePoints': volumePoints,
      'consistencyPoints': consistencyPoints,
      'recencyPoints': recencyPoints,
      'tier': tier,
      'nextTier': nextTier,
      'pointsToNextTier': pointsToNextTier,
      'consistencyRatio': consistencyRatio,
    };
  }

  // ─── WEEKLY REVENUE DATA (for Charts) ─────────────────────────
  /// Returns revenue for each of the last 7 days for bar chart rendering.
  List<Map<String, dynamic>> getWeeklyRevenueData() {
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final nextDay = day.add(const Duration(days: 1));
      final dayRevenue = _orders
          .where((o) =>
              o.createdAt.isAfter(day) &&
              o.createdAt.isBefore(nextDay) &&
              (o.paymentStatus == 'fully_paid' || o.paymentStatus == 'partially_paid' || o.paymentStatus == 'udhaari'))
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      final dayOrders = _orders
          .where((o) => o.createdAt.isAfter(day) && o.createdAt.isBefore(nextDay))
          .length;

      results.add({
        'date': day,
        'revenue': dayRevenue,
        'orders': dayOrders,
        'dayLabel': _getDayLabel(day),
      });
    }
    return results;
  }

  String _getDayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  // ─── LOW-STOCK ALERTS (Velocity-Based) ────────────────────────
  /// Returns products where current stock will run out within 14 days
  /// based on average daily sales velocity.
  List<Map<String, dynamic>> getLowStockAlerts() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final alerts = <Map<String, dynamic>>[];

    for (final product in _products) {
      // Calculate sales velocity (units/day over last 30 days)
      int totalSold = 0;
      for (final order in _orders) {
        if (order.createdAt.isBefore(thirtyDaysAgo)) continue;
        for (final item in order.items) {
          if (item.productId == product.id) {
            totalSold += item.quantity;
          }
        }
      }
      final dailyVelocity = totalSold / 30.0;
      final daysUntilStockout = dailyVelocity > 0
          ? (product.stockLevel / dailyVelocity).round()
          : 999;

      if (daysUntilStockout <= 14 || product.isLowStock) {
        alerts.add({
          'product': product,
          'currentStock': product.stockLevel,
          'dailyVelocity': dailyVelocity,
          'daysUntilStockout': daysUntilStockout,
          'severity': daysUntilStockout <= 3
              ? 'critical'
              : (daysUntilStockout <= 7 ? 'warning' : 'info'),
          'suggestedReorder': (dailyVelocity * 30).ceil(), // 30-day supply
        });
      }
    }
    alerts.sort((a, b) =>
        (a['daysUntilStockout'] as int).compareTo(b['daysUntilStockout'] as int));
    return alerts;
  }

  // ─── BRAND REVENUE BREAKDOWN ──────────────────────────────────
  /// Returns revenue per brand for pie chart rendering.
  List<Map<String, dynamic>> getBrandRevenueBreakdown() {
    final brandRevenue = <String, double>{};
    for (final o in _orders) {
      if (o.paymentStatus == 'fully_paid' || o.paymentStatus == 'partially_paid' || o.paymentStatus == 'udhaari') {
        brandRevenue[o.brand] = (brandRevenue[o.brand] ?? 0) + o.totalAmount;
      }
    }
    final total = brandRevenue.values.fold(0.0, (s, v) => s + v);
    return brandRevenue.entries.map((e) => {
      'brand': e.key,
      'revenue': e.value,
      'percentage': total > 0 ? (e.value / total * 100) : 0.0,
    }).toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  }

  // ═══════════════════════════════════════════════════════════════
  // PAINTER ANALYTICS
  // ═══════════════════════════════════════════════════════════════

  /// Monthly spending for the last 6 months
  List<Map<String, dynamic>> getMonthlySpendingTrend(String painterId) {
    final now = DateTime.now();
    final months = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.month}/${date.year}';
      months[key] = 0.0;
    }

    final pOrders = _orders.where((o) => o.painterId == painterId && o.status == 'delivered');
    for (final order in pOrders) {
      final key = '${order.createdAt.month}/${order.createdAt.year}';
      if (months.containsKey(key)) {
        months[key] = months[key]! + order.totalAmount;
      }
    }

    final result = <Map<String, dynamic>>[];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (final e in months.entries) {
      final parts = e.key.split('/');
      final m = int.parse(parts[0]);
      result.add({
        'month': monthNames[m - 1],
        'spend': e.value,
      });
    }
    return result;
  }

  /// Brand-wise spending breakdown
  List<Map<String, dynamic>> getBrandBreakdownForPainter(String painterId) {
    final pOrders = _orders.where((o) => o.painterId == painterId && o.status == 'delivered');
    final brandSpending = <String, double>{};
    for (final order in pOrders) {
      brandSpending[order.brand] = (brandSpending[order.brand] ?? 0.0) + order.totalAmount;
    }
    
    final total = brandSpending.values.fold(0.0, (s, v) => s + v);
    return brandSpending.entries.map((e) => {
      'brand': e.key,
      'spend': e.value,
      'percentage': total > 0 ? (e.value / total * 100) : 0.0,
    }).toList()..sort((a, b) => (b['spend'] as double).compareTo(a['spend'] as double));
  }

  /// Estimated lifetime savings based on dynamic tier discounts
  double getGoldSavings(String painterId) {
    final pOrders = _orders.where((o) => o.painterId == painterId && o.status == 'delivered');
    // Assuming a rough 10% savings on average for top tier users relative to base retail
    return pOrders.fold(0.0, (s, o) => s + (o.totalAmount * 0.10));
  }

  /// Top ordered products for a specific painter
  List<Map<String, dynamic>> getTopOrderedProducts(String painterId) {
    final pOrders = _orders.where((o) => o.painterId == painterId);
    final productCounts = <String, Map<String, dynamic>>{};
    
    for (final order in pOrders) {
      for (final item in order.items) {
        if (!productCounts.containsKey(item.productId)) {
          productCounts[item.productId] = {
            'id': item.productId,
            'name': item.productName,
            'brand': order.brand,
            'imageUrl': item.productImageUrl,
            'quantity': 0,
            'totalSpend': 0.0,
          };
        }
        productCounts[item.productId]!['quantity'] = (productCounts[item.productId]!['quantity'] as int) + item.quantity;
        productCounts[item.productId]!['totalSpend'] = (productCounts[item.productId]!['totalSpend'] as double) + item.totalPrice;
      }
    }
    
    final list = productCounts.values.toList()
      ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
    
    return list.take(5).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // UDHAARI / LEDGER SYSTEM
  // ═══════════════════════════════════════════════════════════════

  /// Get all ledger entries for a specific painter (newest first)
  List<LedgerEntry> getLedgerForPainter(String painterId) {
    return _ledger
        .where((e) => e.painterId == painterId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Calculate outstanding balance for a painter.
  /// Positive = painter owes money. Negative = overpaid.
  double getOutstandingBalance(String painterId) {
    double balance = 0;
    for (final e in _ledger.where((e) => e.painterId == painterId)) {
      if (e.isCredit) {
        balance += e.amount;
      } else {
        balance -= e.amount;
      }
    }
    return balance;
  }

  /// Get all painters who have outstanding debt (balance > 0)
  List<Map<String, dynamic>> getAllOutstandingBalances() {
    final balances = <String, Map<String, dynamic>>{};
    for (final e in _ledger) {
      final painter = getUserById(e.painterId);
      balances.putIfAbsent(e.painterId, () => {
        'painterId': e.painterId,
        'painterName': painter?.name ?? 'Unknown',
        'balance': 0.0,
        'lastTransaction': e.createdAt,
        'entries': 0,
      });
      final b = balances[e.painterId]!;
      if (e.isCredit) {
        b['balance'] = (b['balance'] as double) + e.amount;
      } else {
        b['balance'] = (b['balance'] as double) - e.amount;
      }
      b['entries'] = (b['entries'] as int) + 1;
      if (e.createdAt.isAfter(b['lastTransaction'] as DateTime)) {
        b['lastTransaction'] = e.createdAt;
      }
    }
    final list = balances.values.toList()
      ..sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));
    return list;
  }

  /// Total outstanding debt across all painters
  double getTotalOutstandingDebt() {
    double total = 0;
    for (final b in getAllOutstandingBalances()) {
      final bal = b['balance'] as double;
      if (bal > 0) total += bal;
    }
    return total;
  }

  /// Number of painters who owe money
  int getPaintersWithDebtCount() {
    return getAllOutstandingBalances()
        .where((b) => (b['balance'] as double) > 0)
        .length;
  }

  /// Add a ledger entry (credit or payment)
  Future<LedgerEntry> addLedgerEntry({
    required String painterId,
    required String type,
    required double amount,
    String? orderId,
    String? note,
    String? createdBy,
  }) async {
    final balance = getOutstandingBalance(painterId);
    final newBalance = type == 'credit'
        ? balance + amount
        : balance - amount;

    final entry = LedgerEntry(
      id: _uuid.v4(),
      painterId: painterId,
      orderId: orderId,
      type: type,
      amount: amount,
      runningBalance: newBalance,
      note: note,
      createdBy: createdBy ?? 'admin',
      createdAt: DateTime.now(),
    );

    // Persist to Supabase FIRST
    try {
      await _sb.from('ledger').insert(entry.toJson());
      _ledger.add(entry);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding ledger entry: $e');
      rethrow;
    }
    return entry;
  }

  /// Get all ledger entries (for admin global view)
  List<LedgerEntry> getAllLedgerEntries() {
    return List.from(_ledger)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ═══════════════════════════════════════════════════════════════
  // CHAT / ORDER NOTES SYSTEM
  // ═══════════════════════════════════════════════════════════════

  /// Get messages for a specific order, sorted oldest first
  List<MessageModel> getMessagesForOrder(String orderId) {
    return _messages.where((m) => m.orderId == orderId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get unread message count for a painter's orders (mock unread system by finding admin messages)
  /// Currently just returns total admin messages to keep simple. Can be upgraded later.
  int getMessageCountForOrder(String orderId) {
    return _messages.where((m) => m.orderId == orderId).length;
  }

  /// Get the last message for an order
  MessageModel? getLastMessageForOrder(String orderId) {
    final msgs = _messages.where((m) => m.orderId == orderId).toList();
    if (msgs.isEmpty) return null;
    msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return msgs.first;
  }

  /// Get orders that have messages, for Admin view
  List<OrderModel> getOrdersWithMessages() {
    final orderIdsWithMessages = _messages.map((m) => m.orderId).toSet();
    final orders =
        _orders.where((o) => orderIdsWithMessages.contains(o.id)).toList();

    orders.sort((a, b) {
      final msgA = getLastMessageForOrder(a.id);
      final msgB = getLastMessageForOrder(b.id);

      final dateA = msgA != null ? msgA.createdAt : a.createdAt;
      final dateB = msgB != null ? msgB.createdAt : b.createdAt;

      return dateB.compareTo(dateA);
    });

    return orders;
  }

  /// Get painter's orders, sorted by latest message or latest order
  List<OrderModel> getPainterOrdersForChatList(String painterId) {
    final orders = _orders.where((o) => o.painterId == painterId).toList();

    orders.sort((a, b) {
      final msgA = getLastMessageForOrder(a.id);
      final msgB = getLastMessageForOrder(b.id);

      final dateA = msgA != null ? msgA.createdAt : a.createdAt;
      final dateB = msgB != null ? msgB.createdAt : b.createdAt;

      return dateB.compareTo(dateA);
    });

    return orders;
  }

  void _initMessageStream() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      _messages = data.map((e) => MessageModel.fromJson(e)).toList();
      notifyListeners();
    });
  }
  
  Future<void> addProduct(ProductModel product) async {
    // Auto-create the brand entry if this is a custom/new brand.
    await ensureBrandExists(product.brand);
    await _sb.from('products').insert(product.toJson()).catchError((e) {
      debugPrint('Error adding product: $e');
      throw Exception('Failed to add product: $e');
    });
    _products.add(product);
    notifyListeners();
    
    // Notify all users about new product
    NotificationService.showNewProduct(
      productName: product.name,
      brand: product.brand,
    );
  }

  void _initOrdersStream() {
    _ordersSubscription?.cancel();
    _ordersSubscription = _sb
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      final newOrders = data.map((e) => OrderModel.fromJson(e)).toList();
      
      // Check for status changes to notify painters
      if (_orders.isNotEmpty) {
        for (final newOrder in newOrders) {
          final oldOrder = _orders.firstWhere((o) => o.id == newOrder.id, orElse: () => newOrder);
          if (newOrder.status != oldOrder.status) {
            // Trigger notification for the painter
            NotificationService.showOrderUpdate(
              orderId: newOrder.id,
              status: newOrder.status,
              brand: newOrder.brand,
            );
          }
        }
      }
      
      _orders = newOrders;
      notifyListeners();
    });
  }

  void _initProductsStream() {
    _productsSubscription?.cancel();
    _productsSubscription = _sb
        .from('products')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      final newProducts = data.map((e) => ProductModel.fromJson(e)).toList();
      _products = newProducts;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _ordersSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }


  /// Send a new message
  Future<MessageModel> sendMessage({
    required String orderId,
    required String senderId,
    required String text,
  }) async {
    final msg = MessageModel(
      id: _uuid.v4(),
      orderId: orderId,
      senderId: senderId,
      text: text,
      createdAt: DateTime.now(),
    );

    _messages.add(msg);
    notifyListeners();

    try {
      await _sb.from('messages').insert(msg.toJson());
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
    return msg;
  }

  /// Get unread message count for admin (active conversations where last message is NOT from admin)
  int getUnreadSupportCount() {
    final supportOrders = getOrdersWithMessages();
    int count = 0;
    for (final order in supportOrders) {
      final lastMsg = getLastMessageForOrder(order.id);
      if (lastMsg != null) {
        final sender = getUserById(lastMsg.senderId);
        // If last message is from a painter, it's "unread" for admin
        if (sender != null && sender.role == 'painter') {
          count++;
        }
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════════
  // SEASONAL / TIME-BASED PRICING
  // ═══════════════════════════════════════════════════════════════

  List<PromotionModel> get getAllPromotions => List.unmodifiable(_promotions);

  List<PromotionModel> getActivePromotions() {
    return _promotions.where((p) => p.isValidNow).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
  }

  /// Calculates the promotional price for a specific base price if an active promo applies
  double? getPromotionalPrice(ProductModel product, double basePrice) {
    final activePromos = getActivePromotions().where((p) => p.brand.toLowerCase() == product.brand.toLowerCase() || p.brand.toLowerCase() == 'all');
    if (activePromos.isEmpty) return null;

    // Apply the best (lowest) promotional price if multiple exist
    double bestPrice = basePrice;
    bool applied = false;

    for (final promo in activePromos) {
      double currentPrice = basePrice;
      if (promo.discountPercent > 0) {
        currentPrice = currentPrice * (1.0 - promo.discountPercent);
      }
      if (promo.discountFlat > 0) {
        currentPrice = currentPrice - promo.discountFlat;
      }
      
      if (currentPrice < bestPrice) {
        bestPrice = currentPrice;
        applied = true;
      }
    }

    return applied ? bestPrice : null;
  }

  Future<void> addPromotion(PromotionModel promotion) async {
    _promotions.add(promotion);
    notifyListeners();

    try {
      await _sb.from('promotions').insert(promotion.toJson());
    } catch (e) {
      debugPrint('Error adding promotion: $e');
    }
  }

  Future<void> deletePromotion(String id) async {
    _promotions.removeWhere((p) => p.id == id);
    notifyListeners();

    try {
      await _sb.from('promotions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting promotion: $e');
    }
  }

  double getTotalSpendForPainter(String painterId) {
    return _orders
        .where((o) => o.painterId == painterId && o.status == 'delivered')
        .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  String _generateInitialReferralCode(String name) {
    final cleanedName = name.trim();
    final prefix = cleanedName.isNotEmpty
        ? (cleanedName.length >= 3
            ? cleanedName.substring(0, 3).toUpperCase()
            : cleanedName.toUpperCase().padRight(3, 'X')) // Pad with 'X' if less than 3 chars
        : 'USR'; // Default prefix for empty name
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    return '$prefix$random';
  }

  void _applyReferralCode(String code, String referredId) {
    try {
      final referrer = _users.firstWhere((u) => u.referralCode == code);
      final referral = ReferralModel(
        id: _uuid.v4(),
        referrerId: referrer.id,
        referredId: referredId,
        referralCode: code,
        bonusPoints: 100, // Fixed bonus for now
        status: 'pending',
        createdAt: DateTime.now(),
      );
      _referrals.add(referral);

      // Persist to Supabase
      _sb.from('referrals').insert(referral.toJson()).then((_) {
        debugPrint('Referral linked successfully');
      }).catchError((e) {
        debugPrint('Error linking referral: $e');
      });
    } catch (e) {
      debugPrint('Referral code invalid or referrer not found: $e');
    }
  }

  List<ReferralModel> getReferralsForPainter(String painterId) {
    return _referrals.where((r) => r.referrerId == painterId).toList();
  }

  // ─── QR CODES ──────────────────────────────────────────────────
  List<QRCodeModel> getAllQRCodes() => List.from(_qrCodes.where((q) => q.status != 'deleted'))..sort((a, b) => 
b.createdAt.compareTo(a.createdAt));

  /// Returns all soft-deleted QR codes.
  List<QRCodeModel> getDeletedQRCodes() => List.from(_qrCodes.where((q) => q.status == 'deleted'))..sort((a, b) =>
      b.createdAt.compareTo(a.createdAt));

  /// Returns all QR codes redeemed by a specific painter (their scan history).
  List<QRCodeModel> getQRHistoryForPainter(String painterId) {
    return _qrCodes
        .where((q) => q.usedBy == painterId && q.status == 'used')
        .toList()
      ..sort((a, b) => (b.usedAt ?? b.createdAt).compareTo(a.usedAt ?? a.createdAt));
  }

  List<QRCodeModel> getScannedQRsForPainter(String painterId) {
    // Show all redeemed QR codes (for backward compatibility with old data)
    return _qrCodes
        .where((q) => q.usedBy == painterId && q.status == 'used')
        .toList()
      ..sort((a, b) => (b.usedAt ?? b.createdAt).compareTo(a.usedAt ?? a.createdAt));
  }

  /// Fetches the painter's redeemed QR codes directly from Supabase, bypassing
  /// the in-memory cache. This avoids issues caused by the local list being
  /// stale or hitting the Supabase default row limit on the bulk select.
  Future<List<QRCodeModel>> fetchScannedQRsForPainter(String painterId) async {
    try {
      final rows = await _sb
          .from('qr_codes')
          .select()
          .eq('used_by', painterId)
          .eq('status', 'used')
          .order('used_at', ascending: false)
          .limit(500);
      final list = (rows as List)
          .map((e) => QRCodeModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Merge into local cache so other screens benefit too.
      for (final q in list) {
        final idx = _qrCodes.indexWhere((c) => c.id == q.id);
        if (idx == -1) {
          _qrCodes.add(q);
        } else {
          _qrCodes[idx] = q;
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching scanned QRs for painter: $e');
      // Fallback to whatever is in the local cache.
      return getScannedQRsForPainter(painterId);
    }
  }

  List<QRCodeModel> getManualQRsForPainter(String painterId) {
    // Show QR codes where qrValue equals the ID (manually typed)
    return _qrCodes
        .where((q) => q.usedBy == painterId && q.status == 'used' && 
               q.qrValue.isNotEmpty && q.qrValue.toUpperCase() == q.id.toUpperCase())
        .toList()
      ..sort((a, b) => (b.usedAt ?? b.createdAt).compareTo(a.usedAt ?? a.createdAt));
  }

  List<QRCodeModel> getQRCodesByBatch(String batchId) {
    return _qrCodes.where((q) => q.batchId == batchId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addQRCodes(List<QRCodeModel> qrs) async {
    try {
      final data = qrs.map((q) => q.toJson()).toList();
      await _sb.from('qr_codes').insert(data);
      _qrCodes.addAll(qrs);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding QR codes: $e');
      throw Exception('Failed to add QR codes: $e');
    }
  }

  Future<void> updateQRCodeBatch({
    required String batchId,
    required int points,
    required String message,
    required String colorScheme,
    String? customLogoBase64,
  }) async {
    final batch = getQRCodesByBatch(batchId);
    if (batch.isEmpty) return;

    final updatedBatch = batch.map((qr) {
      final uri = Uri.parse(qr.qrValue);
      final newUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'points': points.toString(),
      });
      return qr.copyWith(
        points: points,
        message: message,
        colorScheme: colorScheme,
        customLogoBase64: customLogoBase64,
        qrValue: newUri.toString(),
      );
    }).toList();

    try {
      for (final qr in updatedBatch) {
        await _sb.from('qr_codes').update({
          'points': qr.points,
          'message': qr.message,
          'color_scheme': qr.colorScheme,
          'custom_logo_base64': qr.customLogoBase64,
          'qr_value': qr.qrValue,
        }).eq('id', qr.id);
      }
      for (final qr in updatedBatch) {
        final index = _qrCodes.indexWhere((item) => item.id == qr.id);
        if (index != -1) {
          _qrCodes[index] = qr;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating QR batch: $e');
      throw Exception('Failed to update QR batch: $e');
    }
  }

  Future<void> deleteQRCode(String id) async {
    try {
      await _sb.from('qr_codes').update({'status': 'deleted'}).eq('id', id);
      final idx = _qrCodes.indexWhere((q) => q.id == id);
      if (idx != -1) {
        _qrCodes[idx] = _qrCodes[idx].copyWith(status: 'deleted');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting QR code: $e');
      throw Exception('Failed to delete QR code: $e');
    }
  }

  Future<void> deleteQRCodeBatch(String batchId) async {
    try {
      await _sb.from('qr_codes').update({'status': 'deleted'}).eq('batch_id', batchId);
      for (int i = 0; i < _qrCodes.length; i++) {
        if (_qrCodes[i].batchId == batchId) {
          _qrCodes[i] = _qrCodes[i].copyWith(status: 'deleted');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting QR batch: $e');
      throw Exception('Failed to delete QR batch: $e');
    }
  }

  /// Reactivate a soft-deleted QR batch.
  /// Codes that were previously redeemed (have used_by) get status 'used',
  /// others get status 'active'.
  Future<void> reactivateQRCodeBatch(String batchId) async {
    try {
      final batch = _qrCodes.where((q) => q.batchId == batchId).toList();
      if (batch.isEmpty) return;

      // Update unredeemed codes to 'active'
      await _sb.from('qr_codes').update({'status': 'active'}).eq('batch_id', batchId).isFilter('used_by', null);

      // Update redeemed codes to 'used'
      await _sb.from('qr_codes').update({'status': 'used'}).eq('batch_id', batchId).not('used_by', 'is', null);

      // Update local cache
      for (int i = 0; i < _qrCodes.length; i++) {
        if (_qrCodes[i].batchId == batchId) {
          final newStatus = _qrCodes[i].usedBy != null ? 'used' : 'active';
          _qrCodes[i] = _qrCodes[i].copyWith(status: newStatus);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error reactivating QR batch: $e');
      throw Exception('Failed to reactivate QR batch: $e');
    }
  }

  Future<String> redeemQRCode(String id, String userId, {String? scannedValue}) async {
    // 1. Try to find in local cache first
    int i = _qrCodes.indexWhere((q) => q.id.toUpperCase() == id.toUpperCase());
    QRCodeModel? qr;

    if (i == -1) {
      // 2. Not in cache? Fetch directly from Supabase
      try {
        final resp = await _sb.from('qr_codes').select().eq('id', id).maybeSingle();
        if (resp == null) return 'invalid';
        qr = QRCodeModel.fromJson(resp);
        // Add to local list to keep synced
        _qrCodes.add(qr);
        i = _qrCodes.length - 1;
      } catch (e) {
        debugPrint('Error fetching QR from DB: $e');
        return 'error';
      }
    } else {
      qr = _qrCodes[i];
    }

    if (qr == null) return 'invalid';
    if (qr.status == 'used') return 'used';
    if (qr.status == 'expired' || qr.status == 'archived') return 'expired';

    try {
      final now = DateTime.now();
      final user = getUserById(userId);
      final usedByName = user?.name;
      // If scannedValue is provided and different from id, it was camera-scanned
      final qrValue = scannedValue ?? id;
      
      // 1. Update QR Code status in Supabase
      await _sb.from('qr_codes').update({
        'status': 'used',
        'used_by': userId,
        'used_by_name': usedByName,
        'used_at': now.toIso8601String(),
        'scans': qr.scans + 1,
        'qr_value': qrValue,
      }).eq('id', id);

      // 2. Update local QR cache
      if (i != -1 && i < _qrCodes.length) {
        _qrCodes[i] = _qrCodes[i].copyWith(
          status: 'used',
          usedBy: userId,
          usedByName: usedByName,
          usedAt: now,
          scans: qr.scans + 1,
          qrValue: qrValue,
        );
      }

      // 3. Update User Points
      if (user != null) {
        try {
          final newPoints = user.points + qr.points;
          final userIdx = _users.indexWhere((u) => u.id == userId);
          if (userIdx != -1) {
            _users[userIdx] = _users[userIdx].copyWith(points: newPoints);
          }
          await _sb.from('users').update({
            'points': newPoints,
            'updated_at': now.toIso8601String(),
          }).eq('id', userId);
        } catch (pointError) {
          debugPrint('Point update failed: $pointError');
          notifyListeners();
          return 'point_error: $pointError';
        }
      }

      notifyListeners();
      
      // Check milestones after point update
      evaluateMilestonesForPainter(userId);
      
      return 'success:${qr.points}';
    } catch (e) {
      debugPrint('Critical QR redemption error: $e');
      return 'error';
    }
  }

  // ─── REWARD MILESTONES ────────────────────────────────────────
  List<MilestoneModel> get getAllMilestones => List.unmodifiable(_milestones);

  List<MilestoneModel> getMilestonesForPainter(String painterId) {
    return List.from(_milestones)..sort((a, b) => a.targetPoints.compareTo(b.targetPoints));
  }

  MilestoneModel? getNextMilestoneForPainter(String painterId) {
    final user = getUserById(painterId);
    if (user == null) return null;
    final userPoints = user.points;
    final upcoming = _milestones.where((m) => m.targetPoints > userPoints).toList()
      ..sort((a, b) => a.targetPoints.compareTo(b.targetPoints));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  bool hasAchievedMilestone(String painterId, String milestoneId) {
    return _milestoneAchievements.any((m) => m['painter_id'] == painterId && m['milestone_id'] == milestoneId);
  }

  Future<void> addMilestone(MilestoneModel milestone) async {
    _milestones.add(milestone);
    notifyListeners();
    try {
      await _sb.from('milestones').insert(milestone.toJson());
    } catch (e) {
      debugPrint('Error adding milestone: $e');
    }
  }

  Future<void> deleteMilestone(String id) async {
    _milestones.removeWhere((m) => m.id == id);
    notifyListeners();
    try {
      await _sb.from('milestones').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting milestone: $e');
    }
  }

  Future<void> evaluateMilestonesForPainter(String painterId) async {
    final user = getUserById(painterId);
    if (user == null) return;
    
    final achieved = _milestones.where((m) => m.targetPoints <= user.points).toList();
    for (final milestone in achieved) {
      if (!hasAchievedMilestone(painterId, milestone.id)) {
        // Mark as achieved
        final achievement = {
          'id': _uuid.v4(),
          'painter_id': painterId,
          'milestone_id': milestone.id,
          'achieved_at': DateTime.now().toIso8601String(),
        };
        _milestoneAchievements.add(achievement);
        notifyListeners();
        try {
          await _sb.from('milestone_achievements').insert(achievement);
          // Optional: Add to Rewards table
          final reward = RewardModel(
            id: _uuid.v4(),
            painterId: painterId,
            goalId: milestone.id, // Reusing goalId for milestone tracking
            rewardAmount: milestone.targetPoints.toDouble(), // Or 0
            status: 'earned',
            earnedAt: DateTime.now(),
          );
          await addReward(reward);
          NotificationService.showGoalAchieved(
            goalTitle: milestone.rewardTitle,
            rewardAmount: milestone.targetPoints.toDouble(),
          );
        } catch (e) {
          debugPrint('Error saving milestone achievement: $e');
        }
      }
    }
  }

  // ─── STORAGE USAGE CALCULATION ────────────────────────────────

  int _storageUsedBytes = 0;
  int get storageUsedBytes => _storageUsedBytes;
  bool _isFetchingStorage = false;

  Future<void> fetchStorageUsage() async {
    if (_isFetchingStorage) return;
    _isFetchingStorage = true;
    try {
      int totalSize = 0;
      final bucket = _sb.storage.from('paint-images');
      
      // Known base directories within 'paint-images'
      final dirs = ['bills', 'products'];
      for (final dir in dirs) {
        try {
          // List top-level items in these folders
          final items = await bucket.list(path: dir);
          for (final item in items) {
            // Check if it's a file directly inside
            if (item.metadata != null && item.metadata!['size'] != null) {
              totalSize += (item.metadata!['size'] as num).toInt();
            } else if (item.name.isNotEmpty) {
              // It's likely a sub-directory (like bills/orderId/)
              final subItems = await bucket.list(path: '$dir/${item.name}');
              for (final subItem in subItems) {
                if (subItem.metadata != null && subItem.metadata!['size'] != null) {
                  totalSize += (subItem.metadata!['size'] as num).toInt();
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching storage for $dir: $e');
        }
      }
      
      _storageUsedBytes = totalSize;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching overall storage usage: $e');
    } finally {
      _isFetchingStorage = false;
    }
  }

  // ─── POINTS HISTORY ────────────────────────────────────────
  List<dynamic> _pointsHistory = [];

  List<dynamic> getPointsHistory() => List.unmodifiable(_pointsHistory);

  List<Map<String, dynamic>> getPainterPointsHistory(String painterId) {
    final painterHistory = <Map<String, dynamic>>[];
    for (final record in _pointsHistory) {
      final painters = record['painters'] as List;
      try {
        final painterData = painters.firstWhere(
          (p) => p['painter_id'] == painterId,
        );
        painterHistory.add({
          'month': record['month'],
          'points': painterData['points'],
          'reset_date': record['reset_date'],
        });
      } catch (e) {
        // Painter not found in this month's record, skip
        continue;
      }
    }
    return painterHistory;
  }

  Future<void> saveAndResetPoints() async {
    try {
      final now = DateTime.now();
      final monthYear = '${_getMonthName(now.month)}-${now.year.toString().substring(2)}';
      
      // Get all painters
      final allPainters = painters;
      
      if (allPainters.isEmpty) return;

      final snapshots = allPainters.map((p) => {
        'painter_id': p.id,
        'name': p.name,
        'phone': p.phone,
        'points': p.points,
      }).toList();

      // If a record for the same month already exists, reuse its id and
      // overwrite it. Otherwise create a new one and insert at the top.
      final existingIdx = _pointsHistory.indexWhere(
        (r) => r is Map && r['month'] == monthYear,
      );
      final recordId = existingIdx != -1
          ? (_pointsHistory[existingIdx]['id'] as String? ?? _uuid.v4())
          : _uuid.v4();

      final historyRecord = {
        'id': recordId,
        'month': monthYear,
        'reset_date': now.toIso8601String(),
        'painters': snapshots,
      };

      if (existingIdx != -1) {
        _pointsHistory[existingIdx] = historyRecord;
      } else {
        _pointsHistory.insert(0, historyRecord);
      }

      await _sb.from('app_settings').upsert({
        'key': 'points_history',
        'value': _pointsHistory,
      }, onConflict: 'key');

      // Reset all painter points to 0
      for (final painter in allPainters) {
        if (painter.points > 0) {
          final userIdx = _users.indexWhere((u) => u.id == painter.id);
          if (userIdx != -1) {
            _users[userIdx] = _users[userIdx].copyWith(points: 0);
          }
          await _sb.from('users').update({'points': 0, 'updated_at': now.toIso8601String()}).eq('id', painter.id);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving and resetting points: $e');
      rethrow;
    }
  }

  Future<void> deletePointsHistory(String recordId) async {
    _pointsHistory.removeWhere((r) => r['id'] == recordId);
    await _sb.from('app_settings').upsert({'key': 'points_history', 'value': _pointsHistory}, onConflict: 'key');
    notifyListeners();
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

// Riverpod provider — no longer needs SharedPreferences
final dataServiceProvider = ChangeNotifierProvider<DataService>((ref) {
  return DataService();
});
