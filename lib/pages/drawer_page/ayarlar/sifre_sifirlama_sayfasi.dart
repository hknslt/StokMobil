import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capri/core/Color/Colors.dart';

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi.')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata oluştu')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final themed = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Renkler.kahveTon,
        secondary: Renkler.kahveTon,
        onPrimary: Colors.white,
        primaryContainer: Renkler.kahveTon.withOpacity(.14),
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(title: const Text("Şifre sıfırlama"), flexibleSpace: _GradientHeader()),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Renkler.kahveTon.withOpacity(.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı gönderelim.",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Form(
                      key: _f,
                      child: TextFormField(
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendReset,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Gönderiliyor…' : 'Sıfırlama postası gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Ortak stil */
class _GradientHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Renkler.kahveTon, Renkler.kahveTon.withOpacity(.85)],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}
