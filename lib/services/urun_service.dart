// lib/services/urun_service.dart
import 'dart:math';
import 'package:capri/services/fiyat_listesi_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/urun_model.dart';
import '../mock/mock_urun_listesi.dart';
import 'package:capri/services/log_service.dart';

class UrunService {
  static final UrunService _instance = UrunService._internal();
  factory UrunService() => _instance;

  UrunService._internal() {
    _urunler.addAll(mockUrunListesi.map((u) {
      _sonId = max(_sonId, u.id);
      return u;
    }));
  }

  // ---------- In-memory ----------
  final List<Urun> _urunler = [];
  int _sonId = 0;
  List<Urun> get urunler => _urunler;

  void ekleLocal(Urun urun) {
    final yeni = urun.copyWith(id: ++_sonId);
    _urunler.add(yeni);
  }

  void silIndex(int index) {
    _urunler.removeAt(index);
  }

  void guncelleIndex(int index, Urun urun) {
    _urunler[index] = urun;
  }

  void topluSilLocal(List<int> ids) {
    _urunler.removeWhere((u) => ids.contains(u.id));
  }

  // ---------- Firestore ----------
  final _col = FirebaseFirestore.instance.collection('urunler');

  Stream<List<Urun>> dinle() {
    return _col.orderBy('urunAdi').snapshots().map(
          (qs) => qs.docs.map((d) => Urun.fromFirestore(d)).toList(),
        );
  }

  Future<List<Urun>> onceGetir() async {
    final qs = await _col.orderBy('urunAdi').get();
    return qs.docs.map((d) => Urun.fromFirestore(d)).toList();
  }

  Future<int> _yeniNumericId() async {
    final qs = await _col.orderBy('id', descending: true).limit(1).get();
    if (qs.docs.isEmpty) return 1;
    final last = (qs.docs.first.data()['id'] as num?)?.toInt() ?? 0;
    return last + 1;
  }

  Future<void> ekle(Urun urun) async {
    final id = urun.id == 0 ? await _yeniNumericId() : urun.id;
    final data = urun.copyWith(id: id).toMap();
    final ref = await _col.add(data);

    // LOG: ürün eklendi
    await LogService.instance.logUrun(
      action: 'urun_eklendi',
      urunDocId: ref.id,
      urunId: id,
      urunAdi: urun.urunAdi,
      meta: {'renk': urun.renk, 'adet': urun.adet},
    );

    await FiyatListesiService.instance.yeniUrunTumListelereSifirEkle(id);
  }

  Future<void> guncelle(String docId, Urun urun) async {
    await _col.doc(docId).update(urun.toMap());

    await LogService.instance.logUrun(
      action: 'urun_guncellendi',
      urunDocId: docId,
      urunId: urun.id,
      urunAdi: urun.urunAdi,
      meta: {'renk': urun.renk, 'adet': urun.adet},
    );
  }

  Future<void> sil(String docId) async {
    // ürün id/adını log için çek
    final snap = await _col.doc(docId).get();
    final data = snap.data() ?? {};
    final uid = (data['id'] as num?)?.toInt();
    final ad = (data['urunAdi'] as String?) ?? '';

    await _col.doc(docId).delete();

    await LogService.instance.logUrun(
      action: 'urun_silindi',
      urunDocId: docId,
      urunId: uid,
      urunAdi: ad,
    );
  }

  /// ✅ Adedi arttır/azalt (transaction ile: onceki/yeni loglanır)
  Future<void> adetArtir(String docId, int delta) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ref = _col.doc(docId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final d = snap.data() as Map<String, dynamic>;
      final cur = (d['adet'] as num?)?.toInt() ?? 0;
      final yeni = cur + delta;
      tx.update(ref, {'adet': yeni});

      final urunId = (d['id'] as num?)?.toInt();
      final urunAdi = (d['urunAdi'] as String?) ?? '';

      // Transaction içinde log belgesi yazmak yerine transaction SONRASI yazacağız.
      // Bu yüzden log’u burada hazırlayıp TX bitince çalıştırıyoruz:
      Future(() async {
        await LogService.instance.logUrun(
          action: delta >= 0 ? 'stok_eklendi' : 'stok_azaltildi',
          urunDocId: docId,
          urunId: urunId,
          urunAdi: urunAdi,
          meta: {
            'delta': delta,
            'oncekiAdet': cur,
            'yeniAdet': yeni,
          },
        );
      });
    });
  }

  // ---------- Stok yardımcıları ----------
  Future<Map<int, int>> getStocksByNumericIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final chunks = <List<int>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, min(i + 10, ids.length)));
    }

    final result = <int, int>{};
    for (final chunk in chunks) {
      final qs = await _col.where('id', whereIn: chunk).get();
      for (final d in qs.docs) {
        final data = d.data();
        final id = (data['id'] as num).toInt();
        final adet = (data['adet'] as num?)?.toInt() ?? 0;
        result[id] = adet;
      }
    }
    return result;
  }

  /// Hepsi yeterliyse tek transaction içinde stokları düş
  Future<bool> decrementStocksIfSufficient(Map<int, int> istek) async {
    if (istek.isEmpty) return true;

    final refs = <int, DocumentReference<Map<String, dynamic>>>{};
    final ids = istek.keys.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, min(i + 10, ids.length));
      final qs = await _col.where('id', whereIn: chunk).get();
      for (final d in qs.docs) {
        final id = (d.data()['id'] as num).toInt();
        refs[id] = d.reference;
      }
    }

    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final mevcutlar = <int, int>{};
      for (final e in istek.entries) {
        final ref = refs[e.key];
        if (ref == null) return false;
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final cur = (snap.data()?['adet'] as num?)?.toInt() ?? 0;
        mevcutlar[e.key] = cur;
        if (cur < e.value) return false;
      }

      for (final e in istek.entries) {
        final ref = refs[e.key]!;
        final yeni = (mevcutlar[e.key]! - e.value);
        tx.update(ref, {'adet': yeni});
      }
      return true;
    });
  }
}
