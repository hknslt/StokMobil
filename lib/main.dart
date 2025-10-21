import 'dart:io' show Platform;

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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

String get _platformName => Platform.isIOS ? 'ios' : 'android';
bool get _isMobile => Platform.isAndroid || Platform.isIOS;

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BildirimServisi.init();

  if (message.notification != null &&
      (message.notification!.title != null ||
          message.notification!.body != null)) {
    // iOS'ta APNs bildirimi zaten OS tarafından gösterilir; çift bildirim olmasın.
    return;
  }

  final data = message.data;
  final title = data['title'] as String?;
  final body = data['body'] as String?;

  if (title != null || body != null) {
    final fln = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );
    await fln.initialize(initSettings);

    await fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'genel',
          'Genel Bildirimler',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: data['siparisId'],
    );
  }
}

/// Callable'ı güvenli çağır
Future<void> _claimTokenSafe(String token, {String? platform}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('claimDeviceToken');
    await callable.call(<String, dynamic>{
      'token': token,
      'platform': platform ?? _platformName,
    });
  } on FirebaseFunctionsException catch (e) {
    debugPrint('claimDeviceToken error: ${e.code} ${e.message}');
  } catch (e) {
    debugPrint('claimDeviceToken unexpected error: $e');
  }
}

Future<void> _kurBildirimAltyapisi() async {
  // 🔒 Sadece ANDROID + iOS
  if (!_isMobile) return;

  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  // Foreground yönetimi (BildirimServisi içinde local notifications olabilir)
  await BildirimServisi.init();

  // Background mesajlar (yalnız mobile destekli)
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await intl_local.initializeDateFormatting('tr', "");
  Intl.defaultLocale = 'tr';

  // 🔒 Sadece mobile için FCM kur
  await _kurBildirimAltyapisi();

  runApp(const MyApp());

  // 🔒 Aşağıdaki FCM token/oturum dinlemeleri de yalnız mobile
  if (_isMobile) {
    final fcm = FirebaseMessaging.instance;

    // Token yenilenince: claim
    fcm.onTokenRefresh.listen((newToken) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      await _claimTokenSafe(newToken);
    });

    // Oturum durumu değişince claim / token temizleme
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await fcm.getToken();
        if (token != null) await _claimTokenSafe(token);
      } else {
        try {
          await fcm.deleteToken();
        } catch (e) {
          debugPrint('deleteToken error: $e');
        }
      }
    });

    // Açılışta kullanıcı varsa claim
    if (FirebaseAuth.instance.currentUser != null) {
      final token = await fcm.getToken();
      if (token != null) await _claimTokenSafe(token);
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
