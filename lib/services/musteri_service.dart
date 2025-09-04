// lib/services/musteri_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/services/log_service.dart';

class MusteriService {
  MusteriService._();
  static final MusteriService instance = MusteriService._();

  final _col = FirebaseFirestore.instance.collection('musteriler');

  /// Canlı liste (yalnızca guncel == true)
  Stream<List<MusteriModel>> dinle({bool yalnizcaGuncel = true}) {
    Query<Map<String, dynamic>> q = _col.orderBy('firmaAdi');
    if (yalnizcaGuncel) {
      q = _col.where('guncel', isEqualTo: true).orderBy('firmaAdi');
    }
    return q.snapshots().map(
      (qs) => qs.docs.map((d) => MusteriModel.fromFirestore(d)).toList(),
    );
  }

  /// Tek seferlik getir (yalnızca guncel == true)
  Future<List<MusteriModel>> onceGetir({bool yalnizcaGuncel = true}) async {
    Query<Map<String, dynamic>> q = _col.orderBy('firmaAdi');
    if (yalnizcaGuncel) {
      q = _col.where('guncel', isEqualTo: true).orderBy('firmaAdi');
    }
    final qs = await q.get();
    return qs.docs.map((d) => MusteriModel.fromFirestore(d)).toList();
  }

  /// Ekle (docId == id olacak şekilde kaydeder)
  Future<String> ekle(MusteriModel m) async {
    final ref = _col.doc();
    final data = {
      ...m.toMap(),
      'id'    : ref.id,
      // guncel null gelirse varsayılan true kaydedelim
      'guncel': m.guncel,
      // (opsiyonel) createdAt eklemek isterseniz:
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);

    try {
      await LogService.instance.log(
        action: 'musteri_eklendi',
        target: {'type': 'musteri', 'docId': ref.id},
        meta: {
          'firmaAdi': m.firmaAdi,
          'yetkili' : m.yetkili,
          'telefon' : m.telefon,
          'adres'   : m.adres,
        },
      );
    } catch (_) {}

    return ref.id;
  }

  /// Güncelle
  Future<void> guncelle(MusteriModel m) async {
    // guncel null ise mevcut değeri bozmayalım (merge:true)
    await _col.doc(m.id).set({
      ...m.toMap(),
      // createdAt'i koru, istersen dokunma
    }, SetOptions(merge: true));

    try {
      await LogService.instance.log(
        action: 'musteri_guncellendi',
        target: {'type': 'musteri', 'docId': m.id},
        meta: {
          'firmaAdi': m.firmaAdi,
          'yetkili' : m.yetkili,
          'telefon' : m.telefon,
          'adres'   : m.adres,
        },
      );
    } catch (_) {}
  }

  /// Sil
  Future<void> sil(String id) async {
    String? firmaAdi, yetkili, telefon, adres;
    try {
      final snap = await _col.doc(id).get();
      final d = snap.data();
      firmaAdi = (d?['firmaAdi'] as String?)?.trim();
      yetkili  = (d?['yetkili'] as String?)?.trim();
      telefon  = (d?['telefon'] as String?)?.trim();
      adres    = (d?['adres'] as String?)?.trim();
    } catch (_) {}

    await _col.doc(id).delete();

    try {
      await LogService.instance.log(
        action: 'musteri_silindi',
        target: {'type': 'musteri', 'docId': id},
        meta: {
          if (firmaAdi != null && firmaAdi.isNotEmpty) 'firmaAdi': firmaAdi,
          if (yetkili  != null && yetkili.isNotEmpty) 'yetkili' : yetkili,
          if (telefon  != null && telefon.isNotEmpty) 'telefon' : telefon,
          if (adres    != null && adres.isNotEmpty) 'adres'   : adres,
        },
      );
    } catch (_) {}
  }
}
