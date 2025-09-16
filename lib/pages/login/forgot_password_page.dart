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

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

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

      await FirebaseAuth.instance.setLanguageCode('tr');

      final email = await _resolveEmail(raw);
      if (email == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = "Hesap bulunamadı";
          });
        }
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Şifre sıfırlama e-postası gönderildi: $email"),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _firebaseErrToTr(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "İşlem başarısız: $e";
      });
    }
  }

  Future<String?> _resolveEmail(String input) async {
    if (input.contains('@')) return input;

    final lower = input.toLowerCase();

    var qs = await FirebaseFirestore.instance
        .collection('users')
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) {
      qs = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: input)
          .limit(1)
          .get();
    }

    if (qs.docs.isEmpty) return null;
    final data = qs.docs.first.data();
    final email = (data['email'] as String?)?.trim();
    return (email != null && email.isNotEmpty) ? email : null;
  }

  String _firebaseErrToTr(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı yok.';
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
              "E-posta girerseniz doğrudan mail gönderilir.",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inputCtrl,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "E-posta veya kullanıcı adı",
                labelStyle: TextStyle(color: anaRenk),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: anaRenk.withValues(alpha: .35),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: anaRenk, width: 2),
                ),
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: "@ ekle",
                  icon: const Icon(Icons.alternate_email, color: Renkler.kahveTon),
                  onPressed: _loading
                      ? null
                      : () {
                          final t = _inputCtrl;
                          final sel = t.selection;
                          final text = t.text;
                          final start = sel.start >= 0 ? sel.start : text.length;
                          final end = sel.end >= 0 ? sel.end : text.length;
                          t.value = t.value.copyWith(
                            text: text.replaceRange(start, end, '@'),
                            selection: TextSelection.collapsed(offset: start + 1),
                          );
                        },
                ),
              ),
              onSubmitted: (_) => _resetPassword(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: anaRenk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Not: Mail gelmezse spam/junk klasörünü kontrol edin. "
              "Giriş yaptığınız Firebase projesinin Authorized domains listesine "
              "kullandığınız alan adının eklendiğinden emin olun.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
