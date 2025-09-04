import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KullaniciBilgileriSayfasi extends StatefulWidget {
  const KullaniciBilgileriSayfasi({super.key});

  @override
  State<KullaniciBilgileriSayfasi> createState() => _KullaniciBilgileriSayfasiState();
}

class _KullaniciBilgileriSayfasiState extends State<KullaniciBilgileriSayfasi> {
  final _f = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final d = snap.data() ?? {};
      _first.text = (d['firstName'] ?? '').toString();
      _last.text = (d['lastName'] ?? '').toString();
      _username.text = (d['username'] ?? '').toString();
      _phone.text = (d['phone'] ?? '').toString();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    setState(() => _saving = true);
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(u.uid);
      await doc.set({
        'firstName': _first.text.trim(),
        'lastName' : _last.text.trim(),
        'username' : _username.text.trim(),
        'email'    : u.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Auth profil adı (displayName)
      final dn = [_first.text.trim(), _last.text.trim()].where((e) => e.isNotEmpty).join(' ');
      if (dn.isNotEmpty) await u.updateDisplayName(dn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgiler güncellendi')));
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanıcı bilgileri")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _f,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(labelText: "Ad", prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(labelText: "Soyad", prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: "Kullanıcı adı", prefixIcon: Icon(Icons.alternate_email)),
                      validator: (v) {
                        if (v != null && v.trim().length > 0 && v.trim().length < 3) {
                          return 'En az 3 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
