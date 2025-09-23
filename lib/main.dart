// main.dart
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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _fln = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BildirimServisi.init();
}

Future<void> _kurBildirimAltyapisi() async {
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(),
  );
  await _fln.initialize(initSettings);

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

// Yeni: FCM token'ını kaydetme fonksiyonu, token'ı parametre olarak alır.
Future<void> _kaydetFcmToken(String token) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(u.uid)
      .collection('cihazlar')
      .doc(token)
      .set({
        'uid': u.uid,
        'token': token,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

// Yeni: FCM token'ını silme fonksiyonu, token'ı parametre olarak alır.
Future<void> _silFcmToken(String token) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(u.uid)
      .collection('cihazlar')
      .doc(token)
      .delete();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await intl_local.initializeDateFormatting('tr', "");
  Intl.defaultLocale = 'tr';

  await _kurBildirimAltyapisi();

  runApp(const MyApp());

  final fcm = FirebaseMessaging.instance;

  // FCM token yenilendiğinde token'ı günceller.
  fcm.onTokenRefresh.listen((newToken) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance
      .collection('users')
      .doc(u.uid)
      .collection('cihazlar')
      .doc(newToken)
      .set({
        'uid': u.uid,
        'token': newToken,
        'platform': 'android',
        'refreshedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  });

  // Kullanıcının oturum durumu değiştiğinde çalışır.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    final token = await fcm.getToken();
    if (token == null) return;

    if (user != null) {
      // Kullanıcı giriş yaptığında token'ı kaydet
      _kaydetFcmToken(token);
    } else {
      // Kullanıcı çıkış yaptığında token'ı sil
      _silFcmToken(token);
    }
  });

  // Uygulama başladığında kullanıcı zaten giriş yapmışsa token'ı kaydet
  if (FirebaseAuth.instance.currentUser != null) {
    final token = await fcm.getToken();
    if (token != null) {
      _kaydetFcmToken(token);
    }
  }
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