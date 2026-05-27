import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Push notification service using Firebase Cloud Messaging
///
/// Handles:
/// - FCM token management
/// - Foreground notifications
/// - Background notification handling
/// - Notification tap actions (navigate to order detail)
class PushNotificationService {
  static PushNotificationService? _instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String? _fcmToken;
  Function(int)? onOrderNotification; // Callback when order notification tapped

  PushNotificationService._();

  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    await Firebase.initializeApp();

    // Request permission (iOS)
    await _requestPermission();

    // Setup local notifications for foreground
    await _setupLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      await _storage.saveFcmToken(token);
      await _registerTokenWithServer(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Setup background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  /// Setup local notification channel for Android
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          final orderId = data['order_id'] as int?;
          if (orderId != null && onOrderNotification != null) {
            onOrderNotification!(orderId);
          }
        }
      },
    );

    // Create notification channel for Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      AppConfig.NOTIFICATION_CHANNEL_ID,
      AppConfig.NOTIFICATION_CHANNEL_NAME,
      description: AppConfig.NOTIFICATION_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Get FCM token
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _storage.saveFcmToken(_fcmToken!);
        await _registerTokenWithServer(_fcmToken!);
      }
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  /// Register device token with WordPress server
  Future<void> _registerTokenWithServer(String token) async {
    try {
      await _api.registerDeviceToken(token);
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  /// Handle foreground message (show local notification)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'KilifiHub',
        body: notification.body ?? '',
        payload: jsonEncode(data),
      );
    }

    // Play notification sound and vibrate
    _playNotificationEffects();
  }

  /// Handle notification tap (navigate to order)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('Message tap: ${message.messageId}');

    final data = message.data;
    final orderId = int.tryParse(data['order_id']?.toString() ?? '');

    if (orderId != null && onOrderNotification != null) {
      onOrderNotification!(orderId);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      AppConfig.NOTIFICATION_CHANNEL_ID,
      AppConfig.NOTIFICATION_CHANNEL_NAME,
      channelDescription: AppConfig.NOTIFICATION_CHANNEL_DESC,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: Color(AppConfig.PRIMARY_COLOR),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Play vibration for new order
  void _playNotificationEffects() {
    // Vibration is handled by the notification channel settings
  }

  /// Background message handler (must be top-level function)
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    debugPrint('Background message: ${message.messageId}');
  }
}
