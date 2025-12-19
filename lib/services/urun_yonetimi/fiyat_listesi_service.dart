// lib/services/fiyat_listesi_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/fiyat_listesi_model.dart';
import 'package:capri/services/altyapi/log_service.dart';

class FiyatListesiService {
  FiyatListesiService._();
  static final FiyatListesiService instance = FiyatListesiService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fiyatListeleri');

  // ---------------------------------------------------------------------------
  // Aktif liste
  // ---------------------------------------------------------------------------
  FiyatListesi? _aktif;

  FiyatListesi? get aktif => _aktif;
  String? get aktifListeId => _aktif?.id;
  String? get aktifListeAd => _aktif?.ad;
  double get aktifKdv => _aktif?.kdv ?? 0.0;

  void setAktifListe(FiyatListesi l) {
    _aktif = l;
  }

  // ---------------------------------------------------------------------------
  // Listeler
  // ---------------------------------------------------------------------------
  Stream<List<FiyatListesi>> listeleriDinle() {
    return _col
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (qs) =>
              qs.docs.map((d) => FiyatListesi.fromDoc(d.id, d.data())).toList(),
        );
  }

  Future<String> listeOlustur({required String ad, double kdv = 20}) async {
    final ref = await _col.add({
      'ad': ad,
      'kdv': kdv,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // LOG: fiyat listesi oluşturuldu
    try {
      await LogService.instance.log(
        action: 'fiyat_listesi_olusturuldu',
        target: {'type': 'fiyat_listesi', 'docId': ref.id},
        meta: {'ad': ad, 'kdv': kdv},
      );
    } catch (_) {}

    return ref.id;
  }

  Future<String> yeniListe({required String ad, double kdvYuzde = 20}) {
    return listeOlustur(ad: ad, kdv: kdvYuzde);
  }

  Future<String> yeniFiyatListesiOlustur(String ad, {double kdvYuzde = 20}) {
    return listeOlustur(ad: ad, kdv: kdvYuzde);
  }

  Future<void> kdvGuncelle({
    required String listeId,
    required double kdv,
  }) async {
    await _col.doc(listeId).update({'kdv': kdv});

    // LOG: kdv güncellendi
    try {
      await LogService.instance.log(
        action: 'kdv_guncellendi',
        target: {'type': 'fiyat_listesi', 'docId': listeId},
        meta: {'kdv': kdv},
      );
    } catch (_) {}
  }

  Future<void> setKdv(String listeId, double kdvYuzde) {
    return kdvGuncelle(listeId: listeId, kdv: kdvYuzde);
  }

  Stream<FiyatListesi?> listeDinle(String listeId) {
    return _col.doc(listeId).snapshots().map((d) {
      if (!d.exists) return null;
      return FiyatListesi.fromDoc(d.id, d.data()!);
    });
  }

  // ---------------------------------------------------------------------------
  // Ürün fiyatları
  // ---------------------------------------------------------------------------
  Stream<Map<int, double>> urunFiyatlariniDinle(String listeId) {
    return _col.doc(listeId).collection('urunFiyatlari').snapshots().map((qs) {
      final m = <int, double>{};
      for (final d in qs.docs) {
        final data = d.data();
        final uid = (data['urunId'] as num?)?.toInt();
        final nf = (data['netFiyat'] as num?)?.toDouble() ?? 0.0;
        if (uid != null) m[uid] = nf;
      }
      return m;
    });
  }

  Future<void> urunFiyatKaydet({
    required String listeId,
    required int urunId,
    required double netFiyat,
  }) async {
    final doc = _col.doc(listeId).collection('urunFiyatlari').doc('$urunId');
    await doc.set({
      'urunId': urunId,
      'netFiyat': netFiyat,
    }, SetOptions(merge: true));

    // LOG: tek ürün fiyatı kaydedildi
    try {
      await LogService.instance.log(
        action: 'urun_fiyati_kaydedildi',
        target: {'type': 'fiyat_listesi', 'docId': listeId},
        meta: {'urunId': urunId, 'netFiyat': netFiyat},
      );
    } catch (_) {}
  }

  Future<void> setUrunFiyati({
    required String listeId,
    required int urunId,
    required double netFiyat,
  }) {
    return urunFiyatKaydet(
      listeId: listeId,
      urunId: urunId,
      netFiyat: netFiyat,
    );
  }

  /// Bir listeye ait çoklu ürün fiyatını batch ile yaz
  Future<void> urunFiyatlariniKaydet(
    String listeId,
    Map<int, double> fiyatlar,
  ) async {
    final sub = _col.doc(listeId).collection('urunFiyatlari');
    final entries = fiyatlar.entries.toList();
    const chunkSize = 400;
    var toplamYazilan = 0;

    for (var i = 0; i < entries.length; i += chunkSize) {
      final batch = _db.batch();
      final end = (i + chunkSize < entries.length)
          ? i + chunkSize
          : entries.length;
      for (final e in entries.sublist(i, end)) {
        final ref = sub.doc('${e.key}');
        batch.set(ref, {
          'urunId': e.key,
          'netFiyat': e.value,
        }, SetOptions(merge: true));
      }
      await batch.commit();
      toplamYazilan += (end - i);
    }

    // LOG: toplu ürün fiyat yazımı
    try {
      await LogService.instance.log(
        action: 'urun_fiyatlari_toplu_kaydedildi',
        target: {'type': 'fiyat_listesi', 'docId': listeId},
        meta: {'adet': entries.length, 'toplamYazilan': toplamYazilan},
      );
    } catch (_) {}
  }

  Future<double> getNetFiyatOnce(String listeId, int urunId) async {
    final snap = await _col
        .doc(listeId)
        .collection('urunFiyatlari')
        .doc('$urunId')
        .get();
    if (!snap.exists) return 0.0;
    return (snap.data()?['netFiyat'] as num?)?.toDouble() ?? 0.0;
  }

  Stream<double> getNetFiyatDinle(String listeId, int urunId) {
    return _col
        .doc(listeId)
        .collection('urunFiyatlari')
        .doc('$urunId')
        .snapshots()
        .map((d) => (d.data()?['netFiyat'] as num?)?.toDouble() ?? 0.0);
  }

  Future<FiyatListesi?> bulListeAdlaOnce(String ad) async {
    final qs = await _col.where('ad', isEqualTo: ad).limit(1).get();
    if (qs.docs.isEmpty) return null;
    final d = qs.docs.first;
    return FiyatListesi.fromDoc(d.id, d.data());
  }

  Future<double> getNetFiyatByAdOnce(String listeAdi, int urunId) async {
    final l = await bulListeAdlaOnce(listeAdi);
    if (l == null) return 0.0;
    return getNetFiyatOnce(l.id, urunId);
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------
  Future<void> eksikleriSifirla({
    required String listeId,
    required List<int> tumUrunIdleri,
  }) async {
    final entries = Map<int, double>.fromIterable(
      tumUrunIdleri,
      key: (e) => e as int,
      value: (_) => 0.0,
    );
    await urunFiyatlariniKaydet(listeId, entries);

    // LOG: eksikler sıfırlandı
    try {
      await LogService.instance.log(
        action: 'eksikler_sifirlandi',
        target: {'type': 'fiyat_listesi', 'docId': listeId},
        meta: {'urunAdedi': tumUrunIdleri.length},
      );
    } catch (_) {}
  }

  Future<void> yeniUrunTumListelereSifirEkle(int urunId) async {
    final lists = await _col.get();
    const chunkSize = 400;
    var buffer = <DocumentReference>[];
    var toplamYazilan = 0;

    for (final l in lists.docs) {
      final ref = l.reference.collection('urunFiyatlari').doc('$urunId');
      buffer.add(ref);
      if (buffer.length >= chunkSize) {
        final batch = _db.batch();
        for (final r in buffer) {
          batch.set(r, {
            'urunId': urunId,
            'netFiyat': 0.0,
          }, SetOptions(merge: true));
        }
        await batch.commit();
        toplamYazilan += buffer.length;
        buffer = <DocumentReference>[];
      }
    }
    if (buffer.isNotEmpty) {
      final batch = _db.batch();
      for (final r in buffer) {
        batch.set(r, {
          'urunId': urunId,
          'netFiyat': 0.0,
        }, SetOptions(merge: true));
      }
      await batch.commit();
      toplamYazilan += buffer.length;
    }

    // LOG: yeni ürün tüm listelere eklendi (0.0)
    try {
      await LogService.instance.log(
        action: 'yeni_urun_tum_listelere_sifir_ekle',
        target: {'type': 'fiyat_listesi', 'docId': 'ALL'},
        meta: {'urunId': urunId, 'toplamYazilan': toplamYazilan},
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Liste silme (alt koleksiyonlarıyla)
  // ---------------------------------------------------------------------------
  Future<void> listeSil(String listeId) async {
    final ref = _col.doc(listeId);

    // ad & kdv metası (log için)
    String? ad;
    double? kdv;
    try {
      final snap = await ref.get();
      final d = snap.data();
      ad = (d?['ad'] as String?)?.trim();
      kdv = (d?['kdv'] as num?)?.toDouble();
    } catch (_) {}

    const chunkSize = 400;
    var silinenSatir = 0;
    while (true) {
      final qs = await ref.collection('urunFiyatlari').limit(chunkSize).get();
      if (qs.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      silinenSatir += qs.docs.length;
    }

    await ref.delete();

    // LOG: liste silindi
    try {
      await LogService.instance.log(
        action: 'fiyat_listesi_silindi',
        target: {'type': 'fiyat_listesi', 'docId': listeId},
        meta: {
          if (ad != null && ad.isNotEmpty) 'ad': ad,
          if (kdv != null) 'kdv': kdv,
          'silinenUrunFiyatSatiri': silinenSatir,
        },
      );
    } catch (_) {}
  }
}
