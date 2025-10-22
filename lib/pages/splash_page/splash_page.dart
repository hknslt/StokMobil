// lib/pages/splash_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/main.dart';
import 'package:capri/core/models/user.dart';
import 'package:capri/core/Color/Colors.dart'; // YENİ: Renk paletini import ettik

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

// DEĞİŞTİ: Animasyon için 'SingleTickerProviderStateMixin' eklendi
class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // YENİ: Animasyon kontrolcüleri
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // YENİ: Animasyon kurulumu
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Animasyonu başlat
    _controller.forward();

    // Yönlendirme fonksiyonunu çağır
    _yonlendirmeKontrolu();
  }

  @override
  void dispose() {
    // YENİ: Animasyon kontrolcüsünü temizle
    _controller.dispose();
    super.dispose();
  }

  Future<void> _yonlendirmeKontrolu() async {
    // DEĞİŞTİ: Animasyonun bitmesi için bekleme süresini biraz artırdık
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (snap.exists && mounted) {
          final data = snap.data() ?? {};
          MyApp.currentUser = UserModel.fromMap(data, user.uid);
          Navigator.of(context).pushReplacementNamed('/anasayfa');
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Renkler.kahveTon.withOpacity(0.1), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation, 
          child: SafeArea(
            child: Center(
              child: Column(
                children: [
                  const Spacer(flex: 3), 
                  Image.asset("assets/images/capri_logo.png", height: 120),
                  const SizedBox(height: 24),
                  CircularProgressIndicator(
                    color: Renkler.kahveTon.withOpacity(0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yükleniyor...',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                  const Spacer(flex: 4), 

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/dev_logo.png',
                          height: 120, 
                        ),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
