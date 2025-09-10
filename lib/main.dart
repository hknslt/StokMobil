import 'package:capri/services/bildirim_servisi.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_local;
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'core/models/user.dart';
import 'pages/login/login_page.dart';
import 'pages/home/ana_sayfa.dart';
import 'pages/drawer_page/ayarlar/ayarlar_sayfasi.dart';
import 'pages/drawer_page/hakkinda_sayfasi.dart';

// === EK: Bildirimler için ===
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _fln = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BildirimServisi.init();

  // Arka plan mesajı (isteğe bağlı log)
}

Future<void> _kurBildirimAltyapisi() async {
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // iOS/Android izinleri
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(),
  );
  await _fln.initialize(initSettings);

  // Uygulama açıkken gelen mesajlar
  FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
    final n = m.notification;
    if (n != null) {
      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'genel',
            'Genel Bildirimler',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: m.data['siparisId'],
      );
    }
  });
}

Future<void> _kaydetFcmToken() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(u.uid)
      .collection('cihazlar')
      .doc(token)
      .set({
        'uid': u.uid, // EK: uid
        'token': token,
        'platform': 'android', // iOS'ta 'ios'
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await intl_local.initializeDateFormatting('tr', "");
  Intl.defaultLocale = 'tr';

  // === EK: Bildirim altyapısı kurulsun ===
  await _kurBildirimAltyapisi();

  runApp(const MyApp());

  // === EK: login/logout değişiminde token kaydı ===
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) _kaydetFcmToken();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static UserModel? currentUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stok Takip',
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/anasayfa': (context) {
          if (currentUser != null) {
            return AnaSayfa(user: currentUser!);
          } else {
            return const LoginPage();
          }
        },
        '/ayarlar': (context) => const AyarlarSayfasi(),
        '/hakkinda': (context) => const HakkindaSayfasi(),
      },
    );
  }
}
