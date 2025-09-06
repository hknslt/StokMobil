import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_local;

import 'firebase_options.dart';
import 'core/models/user.dart';
import 'pages/login/login_page.dart';
import 'pages/home/ana_sayfa.dart';
import 'pages/drawer_page/ayarlar/ayarlar_sayfasi.dart';
import 'pages/drawer_page/hakkinda_sayfasi.dart';

// ⬇️ Dahili log buffer (aşağıdaki dlog.dart dosyasında)
import 'debug/dlog.dart';
import 'debug/debug_console_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // —— Global error hooks
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    DLog.e('FlutterError', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    DLog.e('PlatformDispatcher.onError', error, stack);
    return true;
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await intl_local.initializeDateFormatting('tr', '');
  Intl.defaultLocale = 'tr';

  // —— Son güvenlik ağı
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    DLog.e('runZonedGuarded', error, stack);
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
          final u = currentUser;
          if (u != null) {
            return AnaSayfa(user: u);
          } else {
            return const LoginPage();
          }
        },
        '/ayarlar': (context) => const AyarlarSayfasi(),
        '/hakkinda': (context) => const HakkindaSayfasi(),
        // ⬇️ Debug konsolu (sadece debug modda kullan)
        if (kDebugMode) '/debug/console': (context) => const DebugConsolePage(),
      },
      // İstersen her sayfaya kolay erişim için sağ alt köşede bug FAB ekleyebilirsin:
      // builder: (ctx, child) => DebugFloatingBug(child: child),
    );
  }
}
