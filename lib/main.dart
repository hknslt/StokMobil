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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
   await intl_local.initializeDateFormatting('tr', "");
  Intl.defaultLocale = 'tr';

  
  runApp(const MyApp());
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
