import 'dart:ui';
import 'package:capri/pages/login/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/main.dart';
import 'package:capri/core/models/user.dart'; 
import 'package:capri/services/auth_service.dart'; 

import 'package:capri/pages/dashboards/admin_dashboard.dart';
import 'package:capri/pages/dashboards/uretim_dashboard.dart';
import 'package:capri/pages/dashboards/pazarlamaci_dashboard.dart';
import 'package:capri/pages/dashboards/sevkiyat_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kullaniciVeyaEpostaController =
      TextEditingController();
  final TextEditingController _sifreController = TextEditingController();

  AnimationController? _anim;
  Animation<double>? _scaleAnim;

  bool _sifreGizli = true;
  bool _yukleniyor = false;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = CurvedAnimation(parent: _anim!, curve: Curves.easeOutBack);
    _anim!.forward();
  }

  @override
  void dispose() {
    _anim?.dispose();
    _kullaniciVeyaEpostaController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _yukleniyor = true);
    final input = _kullaniciVeyaEpostaController.text.trim();
    final password = _sifreController.text;

    await Future.delayed(
      const Duration(milliseconds: 350),
    ); 

    try {
      
      final cred = await _authService.signInWithEmailOrUsername(
        input: input,
        password: password,
      );

      // 2) Profil verisini Firestore'dan çek
      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data() ?? {};

      // 3) UserModel oluştur (core/models/user.dart yeni sürüm olmalı)
      final current = UserModel.fromMap(data, uid);
      MyApp.currentUser = current;

      // 4) Role göre hedef sayfa
      Widget hedef;
      switch (current.role) {
        case 'admin':
          hedef = const AdminDashboard();
          break;
        case 'uretim':
          hedef = const UretimDashboard();
          break;
        case 'pazarlamaci':
          hedef = const PazarlamaciDashboard();
          break;
        case 'sevkiyat':
          hedef = const SevkiyatDashboard();
          break;
        default:
          hedef = const AdminDashboard();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => hedef,
          transitionsBuilder: (_, anim, __, child) {
            final offset = Tween(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim);
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: offset, child: child),
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showErrorSnack(_firebaseErrToTr(e));
    } catch (e) {
      _showErrorSnack('Giriş başarısız: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  String _firebaseErrToTr(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'invalid-email':
        return 'E-posta geçersiz.';
      case 'user-disabled':
        return 'Kullanıcı devre dışı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Bir süre sonra tekrar deneyiniz.';
      default:
        return 'Giriş yapılamadı: ${e.message ?? e.code}';
    }
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anaRenk = Renkler.kahveTon;
    final ikincil = Renkler.kahveTon.withOpacity(.6);

    return Scaffold(
      body: Stack(
        children: [
          // GRADIENT ARKA PLAN
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  anaRenk.withOpacity(.15),
                  anaRenk.withOpacity(.05),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // DEKORATİF LEKELER
          Positioned(
            top: -60,
            left: -30,
            child: _bulut(anaRenk.withOpacity(.20), size: 220),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _bulut(ikincil.withOpacity(.18), size: 260),
          ),

          // İÇERİK
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.65),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(.7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.07),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScaleTransition(
                                  scale:
                                      _scaleAnim ??
                                      const AlwaysStoppedAnimation<double>(1.0),
                                  child: Column(
                                    children: [
                                      // LOGO
                                      Image.asset(
                                        "assets/images/capri_logo.png",
                                        height: 86,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Giriş Yap",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: anaRenk,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Lütfen kullanıcı bilgilerinizi girin",
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // KULLANICI / E-POSTA
                                TextFormField(
                                  controller: _kullaniciVeyaEpostaController,
                                  keyboardType: TextInputType
                                      .emailAddress, // @ için doğru tip
                                  textCapitalization: TextCapitalization.none,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  maxLines: 1,
                                  decoration:
                                      _inputSusu(
                                        context,
                                        label: 'E-posta',
                                        ikon: Icons.person_outline,
                                        anaRenk: anaRenk,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          tooltip: '@ ekle',
                                          icon: const Icon(
                                            color: Renkler.kahveTon,
                                            Icons.alternate_email,
                                          ),
                                          onPressed: () {
                                            final t =
                                                _kullaniciVeyaEpostaController;
                                            final sel = t.selection;
                                            final text = t.text;
                                            final start = sel.start >= 0
                                                ? sel.start
                                                : text.length;
                                            final end = sel.end >= 0
                                                ? sel.end
                                                : text.length;
                                            final newText = text.replaceRange(
                                              start,
                                              end,
                                              '@',
                                            );
                                            t.value = t.value.copyWith(
                                              text: newText,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: start + 1,
                                                  ),
                                              composing: TextRange.empty,
                                            );
                                          },
                                        ),
                                      ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? "Bu alan boş bırakılamaz"
                                      : null,
                                ),

                                const SizedBox(height: 14),

                                // ŞİFRE
                                // ŞİFRE
                                TextFormField(
                                  controller: _sifreController,
                                  obscureText: _sifreGizli,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType
                                      .visiblePassword, // ← şifre klavyesi
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.password],
                                  decoration:
                                      _inputSusu(
                                        context,
                                        label: 'Şifre',
                                        ikon: Icons.lock_outline,
                                        anaRenk: anaRenk,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _sifreGizli = !_sifreGizli,
                                          ),
                                          icon: Icon(
                                            _sifreGizli
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: anaRenk,
                                          ),
                                        ),
                                      ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? "Şifre giriniz"
                                      : null,
                                  onFieldSubmitted: (_) => _girisYap(),
                                ),

                                const SizedBox(height: 18),

                                // GİRİŞ BUTONU
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _yukleniyor ? null : _girisYap,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: anaRenk,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: _yukleniyor
                                          ? const SizedBox(
                                              key: ValueKey('yukl'),
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                              ),
                                            )
                                          : const Text(
                                              key: ValueKey('yazi'),
                                              'Giriş Yap',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Şifrenizi mi unuttunuz?",
                                      style: TextStyle(
                                        color: anaRenk,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ortak Input süsü
  InputDecoration _inputSusu(
    BuildContext context, {
    required String label,
    required IconData ikon,
    required Color anaRenk,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: anaRenk),
      prefixIcon: Icon(ikon, color: anaRenk),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: anaRenk.withValues(alpha: .35), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: anaRenk.withValues(alpha: .35), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: anaRenk, width: 2),
      ),
    );
  }

  // Dekoratif bulut/daire
  Widget _bulut(Color renk, {double size = 240}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: renk,
        boxShadow: [
          BoxShadow(
            color: renk.withOpacity(.35),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
