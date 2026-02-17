import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/services/altyapi/log_service.dart'; // Yolunuz farklıysa düzeltin

class MusteriService {
  MusteriService._();
  static final MusteriService instance = MusteriService._();

  final _col = FirebaseFirestore.instance.collection('musteriler');

  // 💡 YENİ: React'teki getNextId() fonksiyonunun birebir karşılığı
  Future<int> _getNextIdNum() async {
    final qs = await _col.orderBy('idNum', descending: true).limit(1).get();
    if (qs.docs.isEmpty) return 0;

    final data = qs.docs.first.data();
    final lastNum = (data['idNum'] as num?)?.toInt() ?? 0;
    return lastNum;
  }

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

  /// Ekle (Masaüstü uygulaması ile tam uyumlu ID oluşturma)
  Future<String> ekle(MusteriModel m) async {
    // 1. Sıradaki ID numarasını bul ve 6 haneli string'e çevir
    final lastNum = await _getNextIdNum();
    final nextNum = lastNum + 1;
    final docId = nextNum.toString().padLeft(
      6,
      '0',
    ); // React'teki pad6 fonksiyonu

    // 2. Belge referansını bu yeni ID ile oluştur
    final ref = _col.doc(docId);

    final data = {
      ...m.toMap(),
      'id': docId,
      'idNum': nextNum, // Masaüstü için kritik alan
      'guncel': m.guncel,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);

    try {
      await LogService.instance.log(
        action: 'musteri_eklendi',
        target: {'type': 'musteri', 'docId': docId},
        meta: {
          'firmaAdi': m.firmaAdi,
          'yetkili': m.yetkili,
          'telefon': m.telefon,
          'adres': m.adres,
        },
      );
    } catch (_) {}

    return docId; // docId'yi geri döndürüyoruz ki UI kullanabilsin
  }

  /// Güncelle
  Future<void> guncelle(MusteriModel m) async {
    await _col.doc(m.id).set({...m.toMap()}, SetOptions(merge: true));

    try {
      await LogService.instance.log(
        action: 'musteri_guncellendi',
        target: {'type': 'musteri', 'docId': m.id},
        meta: {
          'firmaAdi': m.firmaAdi,
          'yetkili': m.yetkili,
          'telefon': m.telefon,
          'adres': m.adres,
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
      yetkili = (d?['yetkili'] as String?)?.trim();
      telefon = (d?['telefon'] as String?)?.trim();
      adres = (d?['adres'] as String?)?.trim();
    } catch (_) {}

    await _col.doc(id).delete();

    try {
      await LogService.instance.log(
        action: 'musteri_silindi',
        target: {'type': 'musteri', 'docId': id},
        meta: {
          if (firmaAdi != null && firmaAdi.isNotEmpty) 'firmaAdi': firmaAdi,
          if (yetkili != null && yetkili.isNotEmpty) 'yetkili': yetkili,
          if (telefon != null && telefon.isNotEmpty) 'telefon': telefon,
          if (adres != null && adres.isNotEmpty) 'adres': adres,
        },
      );
    } catch (_) {}
  }
}
