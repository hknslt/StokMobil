// lib/pages/ayarlar/bildirim_ayar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capri/core/Color/Colors.dart';

class BildirimAyarSayfasi extends StatefulWidget {
  const BildirimAyarSayfasi({super.key});
  @override
  State<BildirimAyarSayfasi> createState() => _BildirimAyarSayfasiState();
}

class _BildirimAyarSayfasiState extends State<BildirimAyarSayfasi> {
  bool _loading = true;
  bool _saving = false;

  bool siparisOlusturuldu = true;
  bool stokYetersiz = true;
  bool sevkiyataGitti = true;
  bool siparisTamamlandi = true;

  User? get _user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_user!.uid);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final snap = await _userDoc.get();
      final d = snap.data() ?? {};

      final Map<String, dynamic> flat = Map<String, dynamic>.from(
        d['notificationSettings'] ?? {},
      );
      final Map<String, dynamic> nested = Map<String, dynamic>.from(
        (d['ayarlar']?['bildirimler']) ?? {},
      );

      bool _b(dynamic v, {bool def = true}) =>
          v is bool ? v : (v is num ? v != 0 : def);

      setState(() {
        siparisOlusturuldu = _b(
          flat['siparisOlusturuldu'] ?? nested['siparis'] ?? true,
        );
        stokYetersiz = _b(flat['stokYetersiz'] ?? nested['stok'] ?? true);
        sevkiyataGitti = _b(
          flat['sevkiyataGitti'] ?? nested['sevkiyat'] ?? true,
        );
        siparisTamamlandi = _b(
          flat['siparisTamamlandi'] ?? nested['tamamlandi'] ?? true,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ayarlar yüklenemedi: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave({
    required String flatKey,
    required String nestedKey,
    required bool value,
  }) async {
    try {
      setState(() => _saving = true);
      await _userDoc.set({
        'notificationSettings': {flatKey: value},
        'ayarlar': {
          'bildirimler': {nestedKey: value},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final themed = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: Renkler.kahveTon,
        secondary: Renkler.kahveTon,
        primaryContainer: Renkler.kahveTon.withOpacity(.14),
        secondaryContainer: Renkler.kahveTon.withOpacity(.14),
        onPrimary: Colors.white,
      ),
    );

    if (_loading) {
      return Theme(
        data: themed,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bildirim Ayarları'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
          flexibleSpace: _GradientHeader(),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _HintText(
              'Hangi olaylarda bildirim almak istediğini seç. (Değişiklikler anında kaydedilir)',
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _SwitchTile(
                    icon: Icons.add_alert_outlined,
                    title: 'Sipariş oluşturuldu',
                    subtitle: 'Yeni sipariş eklendiğinde',
                    value: siparisOlusturuldu,
                    onChanged: (v) {
                      setState(() => siparisOlusturuldu = v);
                      _toggleSave(
                        flatKey: 'siparisOlusturuldu',
                        nestedKey: 'siparis',
                        value: v,
                      );
                    },
                  ),
                  const Divider(height: 0),
                  _SwitchTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Stok yetersiz',
                    subtitle: 'Sipariş sonrası stok eksik uyarısı',
                    value: stokYetersiz,
                    onChanged: (v) {
                      setState(() => stokYetersiz = v);
                      _toggleSave(
                        flatKey: 'stokYetersiz',
                        nestedKey: 'stok',
                        value: v,
                      );
                    },
                  ),
                  const Divider(height: 0),
                  _SwitchTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Sevkiyata gitti',
                    subtitle: 'Sevkiyat aşamasına geçince',
                    value: sevkiyataGitti,
                    onChanged: (v) {
                      setState(() => sevkiyataGitti = v);
                      _toggleSave(
                        flatKey: 'sevkiyataGitti',
                        nestedKey: 'sevkiyat',
                        value: v,
                      );
                    },
                  ),
                  const Divider(height: 0),
                  _SwitchTile(
                    icon: Icons.check_circle_outline,
                    title: 'Sipariş tamamlandı',
                    subtitle: 'Teslim / tamamlandı durumunda',
                    value: siparisTamamlandi,
                    onChanged: (v) {
                      setState(() => siparisTamamlandi = v);
                      _toggleSave(
                        flatKey: 'siparisTamamlandi',
                        nestedKey: 'tamamlandi',
                        value: v,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- Ortak küçük bileşenler ---------- */
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
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;
  const _HintText(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }
}
  