import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/Color/Colors.dart';

class KullaniciBilgileriSayfasi extends StatefulWidget {
  const KullaniciBilgileriSayfasi({super.key});

  @override
  State<KullaniciBilgileriSayfasi> createState() =>
      _KullaniciBilgileriSayfasiState();
}

class _KullaniciBilgileriSayfasiState extends State<KullaniciBilgileriSayfasi> {
  final _f = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();

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
    super.dispose();
  }

  Future<void> _load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final d = snap.data() ?? {};
      _first.text = (d['firstName'] ?? '').toString();
      _last.text = (d['lastName'] ?? '').toString();
      _username.text = (d['username'] ?? '').toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
        'lastName': _last.text.trim(),
        'username': _username.text.trim(),
        'email': u.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final dn = [
        _first.text.trim(),
        _last.text.trim(),
      ].where((e) => e.isNotEmpty).join(' ');
      if (dn.isNotEmpty) await u.updateDisplayName(dn);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bilgiler güncellendi')));
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _resolveNamePreview() {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final dn = [first, last].where((e) => e.isNotEmpty).join(' ');
    if (dn.isNotEmpty) return dn;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final local = email.contains('@') ? email.split('@').first : email;
    return _username.text.trim().isNotEmpty
        ? _username.text.trim()
        : (local.isNotEmpty ? local : 'Misafir');
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
        secondaryContainer: Renkler.kahveTon.withOpacity(.14),
      ),
    );

    if (_loading) {
      return Theme(
        data: themed,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final namePreview = _resolveNamePreview();
    final initials = namePreview.trim().isNotEmpty
        ? namePreview
              .trim()
              .split(RegExp(r'\s+'))
              .map((e) => e[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'M';

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kullanıcı bilgileri"),
          flexibleSpace: _GradientHeader(),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Renkler.kahveTon,
                            Renkler.kahveTon.withOpacity(.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namePreview,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? '—',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Form(
                  key: _f,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _first,
                        decoration: const InputDecoration(
                          labelText: "Ad",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _last,
                        decoration: const InputDecoration(
                          labelText: "Soyad",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: "Kullanıcı adı",
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isNotEmpty && t.length < 3)
                            return 'En az 3 karakter';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                        ),
                      ),
                    ],
                  ),
                ),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
