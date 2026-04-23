import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const int sosNotificationId = 999;
  static const String sosChannelId = 'sos_alerts';
  static const String sosChannelName = 'SOS Alerts';
  static const String sosChannelDescription =
      'Emergency SOS notifications';

  static Future<void> initialize() async {
    debugPrint('NOTIF: local notification init started');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('NOTIF: notification tapped, payload=${response.payload}');
      },
    );

    // Android 13+ notification permission
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('NOTIF: local notification init finished');
  }

  static Future<void> showSosNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      sosChannelId,
      sosChannelName,
      channelDescription: sosChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SOS Alert',
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      sosNotificationId,
      title,
      body,
      details,
      payload: 'sos_alert',
    );
  }

  static Future<void> cancelSosNotification() async {
    await _localNotifications.cancel(sosNotificationId);
  }

  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}