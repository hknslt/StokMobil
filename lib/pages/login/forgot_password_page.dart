import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/Color/Colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _resetPassword() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = "Bu alan boş olamaz");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Türkçe e-posta metni
      await FirebaseAuth.instance.setLanguageCode('tr');

      // username verildiyse e-postaya çevir
      final email = await _resolveEmail(raw);
      if (email == null) {
        setState(() {
          _loading = false;
          _error = "Hesap bulunamadı";
        });
        return;
      }

      // (İsteğe bağlı) actionCodeSettings ile kendi dönüş linkini kullan:
      // final settings = ActionCodeSettings(
      //   url: 'https://seninsite.com/reset-done',
      //   handleCodeInApp: false, // uygulama içi açmayacaksan false
      //   androidPackageName: 'com.senin.app',
      //   androidInstallApp: true,
      //   iOSBundleId: 'com.senin.app.ios',
      // );
      // await FirebaseAuth.instance.sendPasswordResetEmail(email: email, actionCodeSettings: settings);

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi: $email")),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = _firebaseErrToTr(
          e,
        ); // user-not-found, invalid-email vb. görünür olacak
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "İşlem başarısız: $e";
      });
    }
  }

  Future<String?> _resolveEmail(String input) async {
    if (input.contains('@')) return input;
    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: input)
        .limit(1)
        .get();
    if (qs.docs.isEmpty) return null;
    final email = qs.docs.first.data()['email'] as String?;
    return (email != null && email.trim().isNotEmpty) ? email.trim() : null;
  }

  String _firebaseErrToTr(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'invalid-email':
        return 'E-posta geçersiz.';
      case 'user-disabled':
        return 'Kullanıcı devre dışı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Bir süre sonra tekrar deneyiniz.';
      default:
        return 'Hata: ${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final anaRenk = Renkler.kahveTon;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Şifre Sıfırlama"),
        backgroundColor: anaRenk,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "E-posta adresinizi veya kullanıcı adınızı girin.\n"
              "E-posta girerseniz doğrudan mail gönderilir.\n"
              "Kullanıcı adı girerseniz hesabın e-postası bulunup oraya gönderilir.",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inputCtrl,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: "E-posta veya kullanıcı adı",
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _resetPassword(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: anaRenk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Sıfırlama Maili Gönder",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
