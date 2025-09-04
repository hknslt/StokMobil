import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BildirimAyarlarSayfasi extends StatefulWidget {
  const BildirimAyarlarSayfasi({super.key});

  @override
  State<BildirimAyarlarSayfasi> createState() => _BildirimAyarlarSayfasiState();
}

class _BildirimAyarlarSayfasiState extends State<BildirimAyarlarSayfasi> {
  bool _loading = true;
  bool _saving = false;

  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _orderStatusAlerts = true;
  bool _lowStockAlerts = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final d = doc.data() ?? {};
      _pushEnabled = (d['pushEnabled'] as bool?) ?? _pushEnabled;
      _emailEnabled = (d['emailEnabled'] as bool?) ?? _emailEnabled;
      _orderStatusAlerts = (d['orderStatusAlerts'] as bool?) ?? _orderStatusAlerts;
      _lowStockAlerts = (d['lowStockAlerts'] as bool?) ?? _lowStockAlerts;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'pushEnabled': _pushEnabled,
        'emailEnabled': _emailEnabled,
        'orderStatusAlerts': _orderStatusAlerts,
        'lowStockAlerts': _lowStockAlerts,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar kaydedildi')));
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _tile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, {IconData? icon}) {
    return SwitchListTile(
      secondary: Icon(icon ?? Icons.notifications_none),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirim ayarları")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _tile("Push bildirimleri", "Uygulama içi anlık bildirimler",
                      _pushEnabled, (v) => _pushEnabled = v, icon: Icons.notifications_active),
                  const Divider(height: 0),
                  _tile("E-posta bildirimleri", "E-posta ile bilgilendirmeler",
                      _emailEnabled, (v) => _emailEnabled = v, icon: Icons.alternate_email),
                  const Divider(height: 0),
                  _tile("Sipariş durum uyarıları", "Onay/sevkiyat/tamamlanma değişince haber ver",
                      _orderStatusAlerts, (v) => _orderStatusAlerts = v, icon: Icons.shopping_bag_outlined),
                  const Divider(height: 0),
                  _tile("Düşük stok uyarıları", "Belirlediğin eşiğin altına düştüğünde bildir",
                      _lowStockAlerts, (v) => _lowStockAlerts = v, icon: Icons.inventory_2_outlined),
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
    );
  }
}
