import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/fiyat_listesi_model.dart';

class FiyatListesiService {
  FiyatListesiService._();
  static final FiyatListesiService instance = FiyatListesiService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fiyatListeleri');

  // ---------------------------------------------------------------------------
  // Aktif liste (fiyatlandırma adımında set edilir, diğer adımlarda okunur)
  // ---------------------------------------------------------------------------
  FiyatListesi? _aktif;

  /// Tam nesneye ihtiyaç olursa
  FiyatListesi? get aktif => _aktif;

  /// UI / kayıt için kullanışlı getter’lar
  String? get aktifListeId => _aktif?.id;
  String? get aktifListeAd => _aktif?.ad;
  double get aktifKdv => _aktif?.kdv ?? 0.0;

  /// Fiyatlandırma sayfasında çağırıyorsun (zaten vardı)
  void setAktifListe(FiyatListesi l) {
    _aktif = l;
  }

  // ---------------------------------------------------------------------------
  // Listeler
  // ---------------------------------------------------------------------------
  Stream<List<FiyatListesi>> listeleriDinle() {
    return _col.orderBy('createdAt', descending: false).snapshots().map(
          (qs) => qs.docs
              .map((d) => FiyatListesi.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<String> listeOlustur({required String ad, double kdv = 20}) async {
    final ref = await _col.add({
      'ad': ad,
      'kdv': kdv,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // alias’lar
  Future<String> yeniListe({required String ad, double kdvYuzde = 20}) {
    return listeOlustur(ad: ad, kdv: kdvYuzde);
  }

  Future<String> yeniFiyatListesiOlustur(String ad, {double kdvYuzde = 20}) {
    return listeOlustur(ad: ad, kdv: kdvYuzde);
  }

  Future<void> kdvGuncelle({required String listeId, required double kdv}) {
    return _col.doc(listeId).update({'kdv': kdv});
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
    return _col
        .doc(listeId)
        .collection('urunFiyatlari')
        .snapshots()
        .map((qs) {
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
    await doc.set(
      {'urunId': urunId, 'netFiyat': netFiyat},
      SetOptions(merge: true),
    );
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
    for (var i = 0; i < entries.length; i += chunkSize) {
      final batch = _db.batch();
      final end = (i + chunkSize < entries.length) ? i + chunkSize : entries.length;
      for (final e in entries.sublist(i, end)) {
        final ref = sub.doc('${e.key}');
        batch.set(
          ref,
          {'urunId': e.key, 'netFiyat': e.value},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<double> getNetFiyatOnce(String listeId, int urunId) async {
    final snap =
        await _col.doc(listeId).collection('urunFiyatlari').doc('$urunId').get();
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
  // Yardımcılar (eksikleri 0 ile doldur vb.)
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
  }

  Future<void> yeniUrunTumListelereSifirEkle(int urunId) async {
    final lists = await _col.get();
    const chunkSize = 400;
    var buffer = <DocumentReference>[];

    for (final l in lists.docs) {
      final ref = l.reference.collection('urunFiyatlari').doc('$urunId');
      buffer.add(ref);
      if (buffer.length >= chunkSize) {
        final batch = _db.batch();
        for (final r in buffer) {
          batch.set(r, {'urunId': urunId, 'netFiyat': 0.0}, SetOptions(merge: true));
        }
        await batch.commit();
        buffer = <DocumentReference>[];
      }
    }
    if (buffer.isNotEmpty) {
      final batch = _db.batch();
      for (final r in buffer) {
        batch.set(r, {'urunId': urunId, 'netFiyat': 0.0}, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  // ---------------------------------------------------------------------------
  // Liste silme (alt koleksiyonlarıyla)
  // ---------------------------------------------------------------------------
  Future<void> listeSil(String listeId) async {
    final ref = _col.doc(listeId);

    const chunkSize = 400;
    while (true) {
      final qs = await ref.collection('urunFiyatlari').limit(chunkSize).get();
      if (qs.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }

    await ref.delete();
  }
}
