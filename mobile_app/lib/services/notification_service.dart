import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // Display alert notification on status transition
  static Future<void> showAlertNotification({
    required TempStatus status,
    required double temperature,
  }) async {
    String title = '';
    String body = '';

    switch (status) {
      case TempStatus.high:
        title = '⚠️ TempGuard Alert';
        body = 'Temperature too high: ${temperature.toStringAsFixed(1)}°C';
        break;
      case TempStatus.low:
        title = '❄️ TempGuard Alert';
        body = 'Temperature too low: ${temperature.toStringAsFixed(1)}°C';
        break;
      case TempStatus.normal:
        title = '✅ TempGuard';
        body = 'Temperature returned to normal: ${temperature.toStringAsFixed(1)}°C';
        break;
      default:
        return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tempguard_alerts',
      'TempGuard Temperature Alerts',
      channelDescription: 'Notifications for critical temperature threshold alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'TempGuard Alert',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }
}
