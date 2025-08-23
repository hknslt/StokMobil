import 'dart:math';
import 'package:capri/services/fiyat_listesi_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/urun_model.dart';
import '../mock/mock_urun_listesi.dart';

class UrunService {
  static final UrunService _instance = UrunService._internal();
  factory UrunService() => _instance;

  UrunService._internal() {
    // İstersen buradaki mock başlangıcını kaldırabilirsin
    _urunler.addAll(mockUrunListesi.map((u) {
      _sonId = max(_sonId, u.id);
      return u;
    }));
  }

  // ---------- In-memory (geçiş süreci için) ----------
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

  /// Canlı ürün listesi (Firestore)
  Stream<List<Urun>> dinle() {
    // 'urunAdi' alanına index yoksa doğrudan snapshots() da kullanabilirsin
    return _col.orderBy('urunAdi').snapshots().map(
          (qs) => qs.docs.map((d) => Urun.fromFirestore(d)).toList(),
        );
  }

  /// Tüm ürünleri tek seferlik getir (TypeAhead vb. için)
  Future<List<Urun>> onceGetir() async {
    final qs = await _col.orderBy('urunAdi').get();
    return qs.docs.map((d) => Urun.fromFirestore(d)).toList();
  }

  /// Yeni numeric id oluştur (maks id + 1)
  Future<int> _yeniNumericId() async {
    final qs = await _col.orderBy('id', descending: true).limit(1).get();
    if (qs.docs.isEmpty) return 1;
    final last = (qs.docs.first.data()['id'] as num?)?.toInt() ?? 0;
    return last + 1;
  }

  /// Ekle (Firestore)
  Future<void> ekle(Urun urun) async {
    final id = urun.id == 0 ? await _yeniNumericId() : urun.id;
    final data = urun.copyWith(id: id).toMap();
    await _col.add(data);
    await FiyatListesiService.instance.yeniUrunTumListelereSifirEkle(id);
  }

  /// Güncelle (Firestore, docId ile)
  Future<void> guncelle(String docId, Urun urun) async {
    await _col.doc(docId).update(urun.toMap());
  }

  /// Sil (Firestore, docId ile)
  Future<void> sil(String docId) async {
    await _col.doc(docId).delete();
  }

  /// ✅ Adedi arttır/azalt (delta negatif olabilir)
  Future<void> adetArtir(String docId, int delta) async {
    await _col.doc(docId).update({'adet': FieldValue.increment(delta)});
  }

  // ---------- Stok yardımcıları ----------
  /// Verilen numeric id'ler için {id: adet}
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

    // DocRef'leri hazırla
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

    // Transaction
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      // 1) Yeterlilik kontrolü
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

      // 2) Hepsi yeterliyse düş
      for (final e in istek.entries) {
        final ref = refs[e.key]!;
        final yeni = (mevcutlar[e.key]! - e.value);
        tx.update(ref, {'adet': yeni});
      }
      return true;
    });
  }
}
