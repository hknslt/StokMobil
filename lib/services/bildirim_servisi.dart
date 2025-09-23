import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BildirimServisi {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // iOS izin isteği
    await _fcm.requestPermission();

    // Android local notification ayarları
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _local.initialize(initSettings);

    // Foreground bildirim dinleme
    FirebaseMessaging.onMessage.listen((RemoteMessage mesaj) {
      final bildirim = mesaj.notification;
      if (bildirim != null) {
        _local.show(
          bildirim.hashCode,
          bildirim.title,
          bildirim.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'genel_kanal', 'Genel',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  // Bu cihazın token'ını al
  static Future<String?> tokenAl() => _fcm.getToken();
}