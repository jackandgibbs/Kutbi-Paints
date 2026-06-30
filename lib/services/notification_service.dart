import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/utils/platform_support.dart';

/// Local notification service for order updates, low-stock alerts,
/// and goal achievements.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize the notification plugin
  static Future<void> init() async {
    if (_initialized || !PlatformSupport.supportsLocalNotifications) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    
    // Explicitly request permission for Android 13+
    await requestPermissions();
    
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    if (!PlatformSupport.supportsLocalNotifications) return;
    
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Show a notification for order status update
  static Future<void> showOrderUpdate({
    required String orderId,
    required String status,
    required String brand,
  }) async {
    final statusText = _getStatusText(status);
    await _show(
      id: orderId.hashCode,
      title: '🎨 Order $statusText',
      body: 'Your $brand order has been $statusText.',
      channel: 'orders',
      channelName: 'Order Updates',
    );
  }

  /// Show a notification for low stock alert
  static Future<void> showLowStockAlert({
    required String productName,
    required int currentStock,
    required int daysUntilStockout,
  }) async {
    await _show(
      id: productName.hashCode,
      title: '⚠️ Low Stock Alert',
      body: '$productName: $currentStock units left (~$daysUntilStockout days)',
      channel: 'alerts',
      channelName: 'Stock Alerts',
    );
  }

  /// Show a notification for goal achievement
  static Future<void> showGoalAchieved({
    required String goalTitle,
    required double rewardAmount,
  }) async {
    await _show(
      id: goalTitle.hashCode,
      title: '🏆 Goal Achieved!',
      body: '$goalTitle — Reward: ₹${rewardAmount.toStringAsFixed(0)}',
      channel: 'rewards',
      channelName: 'Rewards',
    );
  }

  /// Show a notification for offline sync
  static Future<void> showSyncComplete(int count) async {
    await _show(
      id: 99999,
      title: '✅ Sync Complete',
      body: '$count pending orders synced successfully.',
      channel: 'sync',
      channelName: 'Sync Status',
    );
  }

  /// Show notification when admin uploads a bill for a painter's order
  static Future<void> showBillUploaded({
    required String orderId,
    required String brand,
    required double amount,
  }) async {
    await _show(
      id: orderId.hashCode + 1000,
      title: '🧾 Bill Uploaded',
      body: 'Bill for your $brand order: ₹${amount.toStringAsFixed(0)}',
      channel: 'bills_v2',
      channelName: 'Bill Updates',
    );
  }

  /// Show notification when a product is marked out of stock
  static Future<void> showOutOfStockNotification({
    required String productName,
    required String brand,
  }) async {
    await _show(
      id: productName.hashCode + 2000,
      title: '🚫 Product Out of Stock',
      body: '$productName ($brand) is now out of stock.',
      channel: 'stock',
      channelName: 'Stock Updates',
    );
  }

  /// Show notification when a product is back in stock
  static Future<void> showBackInStockNotification({
    required String productName,
    required String brand,
  }) async {
    await _show(
      id: productName.hashCode + 3000,
      title: '✅ Back in Stock',
      body: '$productName ($brand) is now available again!',
      channel: 'stock',
      channelName: 'Stock Updates',
    );
  }

  /// Show notification when a new product is added
  static Future<void> showNewProduct({
    required String productName,
    required String brand,
  }) async {
    await _show(
      id: productName.hashCode + 4000,
      title: '✨ New Arrival: $brand',
      body: '$productName is now available. Check it out!',
      channel: 'new_arrivals',
      channelName: 'New Products',
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
  }) async {
    if (!PlatformSupport.supportsLocalNotifications) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        channel,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true, // This helps in showing heads-up while in foreground
        category: AndroidNotificationCategory.message,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'preparing':
        return 'Being Prepared';
      case 'dispatched':
        return 'Dispatched';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }
}
