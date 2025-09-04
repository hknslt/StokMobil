import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SifreSifirlamaSayfasi extends StatefulWidget {
  const SifreSifirlamaSayfasi({super.key});

  @override
  State<SifreSifirlamaSayfasi> createState() => _SifreSifirlamaSayfasiState();
}

class _SifreSifirlamaSayfasiState extends State<SifreSifirlamaSayfasi> {
  final _f = GlobalKey<FormState>();
  final _email = TextEditingController(text: FirebaseAuth.instance.currentUser?.email ?? '');

  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_f.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi.')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata oluştu')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Şifre sıfırlama")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _f,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Kayıtlı e-posta adresinizi girin:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "E-posta",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final x = v?.trim() ?? '';
                  if (x.isEmpty) return 'E-posta gerekli';
                  if (!x.contains('@')) return 'Geçerli e-posta girin';
                  return null;
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendReset,
                  icon: const Icon(Icons.send),
                  label: Text(_sending ? 'Gönderiliyor…' : 'Sıfırlama postası gönder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
