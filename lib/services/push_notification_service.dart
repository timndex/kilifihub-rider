import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Push notification service
///
/// CURRENTLY RUNNING IN LOCAL-ONLY MODE (no Firebase).
/// After setting up Firebase, uncomment the Firebase code in:
/// 1. pubspec.yaml (add firebase_core and firebase_messaging)
/// 2. main.dart (add Firebase.initializeApp())
/// 3. This file (uncomment Firebase sections)
///
/// For now, this handles local notifications only.
class PushNotificationService {
  static PushNotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String? _fcmToken;
  Function(int)? onOrderNotification;

  PushNotificationService._();

  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  String? get fcmToken => _fcmToken;

  /// Initialize local notifications
  /// After Firebase setup, add Firebase initialization here
  Future<void> initialize() async {
    // TODO: After Firebase setup, add:
    // await Firebase.initializeApp();
    // await _requestPermission();
    // await _setupFirebaseMessaging();

    await _setupLocalNotifications();
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
          try {
            final payload = response.payload!;
            if (payload.contains('order_id')) {
              final orderId = int.tryParse(payload.replaceAll(RegExp(r'[^0-9]'), ''));
              if (orderId != null && onOrderNotification != null) {
                onOrderNotification!(orderId);
              }
            }
          } catch (e) {
            debugPrint('Notification payload parse error: $e');
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

  /// Show a local notification (works without Firebase)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // NOTE: Cannot use 'const' here because BigTextStyleInformation(body)
    // uses a runtime parameter
    final AndroidNotificationDetails androidDetails =
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
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
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
}
