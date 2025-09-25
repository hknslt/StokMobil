// lib/pages/drawer_page/ayarlar/bildirim_ayarlar_sayfasi.dart
import 'dart:io' show Platform;

import 'package:capri/core/Color/Colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class BildirimAyarSayfasi extends StatefulWidget {
  const BildirimAyarSayfasi({super.key});

  @override
  State<BildirimAyarSayfasi> createState() => _BildirimAyarSayfasiState();
}

class _BildirimAyarSayfasiState extends State<BildirimAyarSayfasi> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _fcm = FirebaseMessaging.instance;

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  // --- Global toggle ---
  bool enabled = true;

  // --- Flat (notificationSettings) toggles ---
  bool siparisOlusturuldu = true;
  bool uretimde = true; // <-- stokYetersiz yerine
  bool sevkiyataGitti = true;
  bool siparisTamamlandi = true;

  // --- Permission snapshot ---
  bool _hasPushPermission = true;
  String? _token;

  void _setDirty(VoidCallback fn) {
    fn();
    if (!_dirty) _dirty = true;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _loading = true);
    final u = _auth.currentUser;
    if (u == null) {
      _loading = false;
      setState(() {});
      return;
    }

    try {
      final snap = await _db.collection('users').doc(u.uid).get();
      final data = snap.data() ?? {};

      final flat = (data['notificationSettings'] as Map?) ?? {};
      final ayarlar = (data['ayarlar'] as Map?) ?? {};
      final nested = (ayarlar['bildirimler'] as Map?) ?? {};

      final flatEnabled = !(flat['enabled'] == false);
      final nestedEnabled = !(nested['enabled'] == false);
      enabled = flatEnabled && nestedEnabled;

      bool _pick(String flatKey, String nestedKey) {
        if (flat[flatKey] == false) return false;
        if (flat.containsKey(flatKey)) return flat[flatKey] != false;
        if (nested[nestedKey] == false) return false;
        if (nested.containsKey(nestedKey)) return nested[nestedKey] != false;
        return true;
      }

      siparisOlusturuldu = _pick('siparisOlusturuldu', 'siparis');
      uretimde = _pick('uretimde', 'uretimde'); // <-- yeni anahtar
      sevkiyataGitti = _pick('sevkiyataGitti', 'sevkiyat');
      siparisTamamlandi = _pick('siparisTamamlandi', 'tamamlandi');

      final settings = await _fcm.getNotificationSettings();
      _hasPushPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      _token = await _fcm.getToken();

      _dirty = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ayarlar yüklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _izinIste() async {
    try {
      final perm = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: Platform.isIOS,
        sound: true,
      );
      setState(() {
        _hasPushPermission =
            perm.authorizationStatus == AuthorizationStatus.authorized ||
            perm.authorizationStatus == AuthorizationStatus.provisional;
      });
      if (!_hasPushPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bildirim izni verilmedi. Sistem ayarlarından açabilirsiniz.',
              ),
            ),
          );
        }
      } else {
        _token = await _fcm.getToken();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İzin istenirken hata: $e')));
      }
    }
  }

  Future<void> _kaydet() async {
    final u = _auth.currentUser;
    if (u == null) return;

    setState(() => _saving = true);

    try {
      final flatUpdate = {
        'enabled': enabled,
        'siparisOlusturuldu': siparisOlusturuldu,
        'uretimde': uretimde, // <-- yeni anahtar
        'sevkiyataGitti': sevkiyataGitti,
        'siparisTamamlandi': siparisTamamlandi,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final nestedUpdate = {
        'enabled': enabled,
        'siparis': siparisOlusturuldu,
        'uretimde': uretimde, // <-- yeni anahtar
        'sevkiyat': sevkiyataGitti,
        'tamamlandi': siparisTamamlandi,
      };

      await _db.collection('users').doc(u.uid).set({
        'notificationSettings': flatUpdate,
        'ayarlar': {'bildirimler': nestedUpdate},
      }, SetOptions(merge: true));

      _dirty = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim ayarları kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: Renkler.kahveTon,
              ),
              const SizedBox(width: 8),
              const Text(
                'Bildirim Ayarları',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Spacer(),
              if (_dirty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Renkler.anaMavi.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Kaydedilmemiş',
                    style: TextStyle(color: Renkler.anaMavi),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sipariş yaşam döngüsüne ait bildirimleri buradan yönetebilirsin.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cihaz İzni',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _hasPushPermission
                    ? Icons.verified_outlined
                    : Icons.info_outline,
                color: _hasPushPermission ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasPushPermission
                      ? 'Bu cihaz için bildirim izni aktif.'
                      : 'Bu cihazda bildirim izni kapalı görünüyor.',
                ),
              ),
              TextButton(
                onPressed: _izinIste,
                style: TextButton.styleFrom(foregroundColor: Renkler.kahveTon),
                child: const Text('İzin İste'),
              ),
            ],
          ),
          if (_token != null) ...[const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: SwitchListTile.adaptive(
        activeColor: Renkler.kahveTon,
        value: enabled,
        onChanged: (v) => _setDirty(() => enabled = v),
        title: const Text('Bildirimleri Aç'),
        subtitle: const Text(
          'Genel anahtar – kapatırsan tüm olaylar susturulur',
        ),
        secondary: Icon(
          enabled
              ? Icons.notifications_active
              : Icons.notifications_off_outlined,
          color: Renkler.kahveTon,
        ),
      ),
    );
  }

  Widget _buildEventSwitches() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            activeColor: Renkler.kahveTon,
            value: siparisOlusturuldu,
            onChanged: enabled
                ? (v) => _setDirty(() => siparisOlusturuldu = v)
                : null,
            title: const Text('Sipariş oluşturuldu'),
            subtitle: const Text('Yeni sipariş girişi yapıldığında'),
            secondary: Icon(
              Icons.add_shopping_cart_outlined,
              color: Renkler.kahveTon,
            ),
          ),
          const Divider(height: 0),
          SwitchListTile.adaptive(
            activeColor: Renkler.kahveTon,
            value: uretimde,
            onChanged: enabled ? (v) => _setDirty(() => uretimde = v) : null,
            title: const Text('Sipariş üretimde'),
            subtitle: const Text('Sipariş üretime alındığında'),
            secondary: Icon(Icons.build_outlined, color: Renkler.kahveTon),
          ),
          const Divider(height: 0),
          SwitchListTile.adaptive(
            activeColor: Renkler.kahveTon,
            value: sevkiyataGitti,
            onChanged: enabled
                ? (v) => _setDirty(() => sevkiyataGitti = v)
                : null,
            title: const Text('Sevkiyat aşaması'),
            subtitle: const Text('Sipariş sevkiyata çıktığında'),
            secondary: Icon(
              Icons.local_shipping_outlined,
              color: Renkler.kahveTon,
            ),
          ),
          const Divider(height: 0),
          SwitchListTile.adaptive(
            activeColor: Renkler.kahveTon,
            value: siparisTamamlandi,
            onChanged: enabled
                ? (v) => _setDirty(() => siparisTamamlandi = v)
                : null,
            title: const Text('Sipariş tamamlandı'),
            subtitle: const Text('Teslim edildiğinde'),
            secondary: const Icon(
              Icons.verified_outlined,
              color: Renkler.kahveTon,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Renkler.anaMavi, Renkler.kahveTon.withOpacity(.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: (!_dirty || _saving) ? null : _kaydet,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, color: Colors.white),
            label: Text(
              'Kaydet',
              style: TextStyle(
                color: (!_dirty || _saving) ? Colors.white70 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildPermissionCard(),
                  const SizedBox(height: 12),
                  _buildMasterSwitch(),
                  const SizedBox(height: 12),
                  _buildEventSwitches(),
                ],
              ),
            ),
    );
  }
}
