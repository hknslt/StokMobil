import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BildirimServisi {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'genel',
    'Genel Bildirimler',
    importance: Importance.max,
    priority: Priority.high,
  );
  static const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails();
  static const NotificationDetails _notifDetails =
      NotificationDetails(android: _androidDetails, iOS: _iosDetails);

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        InitializationSettings(android: androidInit, iOS: DarwinInitializationSettings());
    await _local.initialize(initSettings);

    // Foreground: önce data, yoksa notification
    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final data = m.data;
      final notif = m.notification;

      final hasApnsAlert = notif != null &&
          (notif.title != null || notif.body != null);

      final title = (data['title'] as String?) ?? notif?.title;
      final body  = (data['body']  as String?) ?? notif?.body;

      // iOS'ta APNs alert varsa OS zaten gösterir → duplicate olmasın
      if (hasApnsAlert) return;

      if (title != null || body != null) {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          _notifDetails,
          payload: data['siparisId'],
        );
      }
    });
  }

  static Future<String?> tokenAl() => _fcm.getToken();
}
