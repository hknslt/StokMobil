// lib/services/siparis_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/log_service.dart';

class SiparisService {
  static final SiparisService _instance = SiparisService._internal();
  factory SiparisService() => _instance;
  SiparisService._internal();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('siparisler');

  // ------------------ GENEL AKIŞLAR ------------------

  Stream<List<SiparisModel>> hepsiDinle() {
    return _col
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((qs) => qs.docs
            .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
            .toList());
  }

  Stream<List<SiparisModel>> dinle({SiparisDurumu? sadeceDurum}) {
    Query<Map<String, dynamic>> q = _col;
    if (sadeceDurum != null) {
      q = q.where('durum', isEqualTo: sadeceDurum.name);
    }
    q = q.orderBy('tarih', descending: true);
    return q.snapshots().map((qs) => qs.docs
        .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
        .toList());
  }

  Stream<List<SiparisModel>> beklemedeDinle() =>
      dinle(sadeceDurum: SiparisDurumu.beklemede);
  Stream<List<SiparisModel>> uretimdeDinle() =>
      dinle(sadeceDurum: SiparisDurumu.uretimde);
  Stream<List<SiparisModel>> sevkiyattaDinle() =>
      dinle(sadeceDurum: SiparisDurumu.sevkiyat);
  Stream<List<SiparisModel>> reddedilenDinle() =>
      dinle(sadeceDurum: SiparisDurumu.reddedildi);

  /// ✅ TAMAMLANANLAR (analiz/geçmiş için)
  Stream<List<SiparisModel>> tamamlananDinle({
    DateTime? baslangic,
    DateTime? bitis,
  }) {
    Query<Map<String, dynamic>> q =
        _col.where('durum', isEqualTo: SiparisDurumu.tamamlandi.name);

    if (baslangic != null) {
      final start = DateTime(baslangic.year, baslangic.month, baslangic.day);
      q = q.where('islemeTarihi',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (bitis != null) {
      final next =
          DateTime(bitis.year, bitis.month, bitis.day).add(const Duration(days: 1));
      q = q.where('islemeTarihi', isLessThan: Timestamp.fromDate(next));
    }

    q = q.orderBy('islemeTarihi', descending: false);
    return q.snapshots().map((qs) => qs.docs
        .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
        .toList());
  }

  // ------------------ HELPER ------------------

  /// Siparişteki ürünleri {urunId: toplamAdet} haritasına çevir.
  Map<int, int> _istekHaritasi(SiparisModel s) {
    final map = <int, int>{};
    for (final su in s.urunler) {
      final id = int.tryParse(su.id);
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + su.adet;
    }
    return map;
  }

  // ------------------ CRUD ------------------

  Future<String> ekle(SiparisModel siparis) async {
    final map = siparis.toMap();
    map['netTutar'] ??= siparis.netToplam;
    map['kdvOrani'] ??= siparis.kdvOrani ?? 0.0;
    map['kdvTutar'] ??= siparis.kdvToplam;
    map['brutTutar'] ??= siparis.brutToplam;

    final ref = await _col.add(map);

    // LOG: sipariş eklendi
    await LogService.instance.logSiparis(
      action: 'siparis_eklendi',
      siparisId: ref.id,
      meta: {
        'musteriId': siparis.musteri.id,
        'musteriAdi': siparis.musteri.firmaAdi ?? siparis.musteri.yetkili ?? '',
        'net': map['netTutar'],
        'kdvOrani': map['kdvOrani'],
        'kdvTutar': map['kdvTutar'],
        'brut': map['brutTutar'],
        'kalemSayisi': siparis.urunler.length,
      },
    );

    return ref.id;
  }

  Future<void> guncelle(String docId, SiparisModel siparis) async {
    await _col.doc(docId).set(siparis.toMap(), SetOptions(merge: true));

    // LOG: sipariş güncellendi (özet)
    await LogService.instance.logSiparis(
      action: 'siparis_guncellendi',
      siparisId: docId,
      meta: {
        'durum': siparis.durum.name,
        'musteriId': siparis.musteri.id,
      },
    );
  }

  Future<void> sil(String docId) async {
    await _col.doc(docId).delete();
    await LogService.instance.logSiparis(
      action: 'siparis_silindi',
      siparisId: docId,
    );
  }

  /// Tek siparişi canlı dinle (detay)
  Stream<SiparisModel?> tekDinle(String docId) {
    return _col.doc(docId).snapshots().map((d) {
      if (!d.exists) return null;
      return SiparisModel.fromMap(d.data()!).copyWith(docId: d.id);
    });
  }

  /// 👇 DURUM GÜNCELLEME
  Future<void> guncelleDurum(
    String docId,
    SiparisDurumu yeni, {
    bool islemeTarihiniAyarla = false,
    DateTime? islemeTarihi,
  }) async {
    if (yeni == SiparisDurumu.sevkiyat) {
      final snap = await _col.doc(docId).get();
      if (!snap.exists) {
        throw StateError('Sipariş bulunamadı: $docId');
      }
      final sip = SiparisModel.fromMap(snap.data()!).copyWith(docId: snap.id);

      final istek = _istekHaritasi(sip);
      final ok = await UrunService().decrementStocksIfSufficient(istek);

      final durum = ok ? SiparisDurumu.sevkiyat : SiparisDurumu.uretimde;
      await _col.doc(docId).update({'durum': durum.name});

      // LOG: sevkiyata alındı / üretime alındı
      if (ok) {
        await LogService.instance.logSiparis(
          action: 'siparis_sevkiyata_alindi',
          siparisId: docId,
          meta: {'urunler': istek}, // {urunId: adet}
        );
        // Ayrıntılı stok düşüş logları (her kalem için)
        for (final su in sip.urunler) {
          final uid = int.tryParse(su.id);
          await LogService.instance.logUrun(
            action: 'stok_azaltildi',
            urunDocId: null,
            urunId: uid,
            urunAdi: su.urunAdi,
            meta: {
              'adet': su.adet,
              'reason': 'sevkiyat',
              'siparisId': docId,
            },
          );
        }
      } else {
        await LogService.instance.logSiparis(
          action: 'siparis_uretime_alindi',
          siparisId: docId,
        );
      }
      return;
    }

    if (yeni == SiparisDurumu.tamamlandi) {
      final data = <String, dynamic>{'durum': yeni.name};
      if (islemeTarihiniAyarla) {
        data['islemeTarihi'] = islemeTarihi != null
            ? Timestamp.fromDate(islemeTarihi)
            : FieldValue.serverTimestamp();
      }
      await _col.doc(docId).update(data);

      // LOG: tamamlandı
      await LogService.instance.logSiparis(
        action: 'siparis_tamamlandi',
        siparisId: docId,
        meta: {
          'islemeTarihi_set': islemeTarihiniAyarla,
        },
      );
      return;
    }

    await _col.doc(docId).update({'durum': yeni.name});
    await LogService.instance.logSiparis(
      action: 'siparis_durum_guncellendi',
      siparisId: docId,
      meta: {'yeniDurum': yeni.name},
    );
  }

  // Eski alias'lar
  Future<void> durumGuncelle(String docId, SiparisDurumu durum) =>
      guncelleDurum(docId, durum);
  Future<void> durumuGuncelle(String docId, SiparisDurumu durum) =>
      guncelleDurum(docId, durum);

  /// 🔹 Sadece bu siparişi sevkiyata geçirmeyi dener.
  ///    (Stok yeterse düşer ve 'sevkiyat', yetmezse 'uretimde' kalır)
  Future<bool> sevkiyataGecir(String docId) async {
    final snap = await _col.doc(docId).get();
    if (!snap.exists) throw StateError('Sipariş bulunamadı: $docId');
    final sip = SiparisModel.fromMap(snap.data()!).copyWith(docId: snap.id);

    final istek = _istekHaritasi(sip);
    final ok = await UrunService().decrementStocksIfSufficient(istek);
    await _col.doc(docId).update(
      {'durum': ok ? SiparisDurumu.sevkiyat.name : SiparisDurumu.uretimde.name},
    );

    // LOG
    await LogService.instance.logSiparis(
      action: ok ? 'siparis_sevkiyata_alindi' : 'siparis_uretime_alindi',
      siparisId: docId,
      meta: ok ? {'urunler': istek} : null,
    );
    if (ok) {
      for (final su in sip.urunler) {
        final uid = int.tryParse(su.id);
        await LogService.instance.logUrun(
          action: 'stok_azaltildi',
          urunDocId: null,
          urunId: uid,
          urunAdi: su.urunAdi,
          meta: {'adet': su.adet, 'reason': 'sevkiyat', 'siparisId': docId},
        );
      }
    }

    return ok;
  }

  /// 🔹 FIFO: üretimdeki siparişleri sırayla dener; stok yeterli olanlar
  ///    için stok düşüp 'sevkiyat'a alır. Kaç siparişin geçtiğini döner.
  Future<int> allocateFIFOAcrossProduction() async {
    final adaylar = await getirByDurumOnce(SiparisDurumu.uretimde)
      ..sort((a, b) => a.tarih.compareTo(b.tarih)); // FIFO

    int counter = 0;
    for (final s in adaylar) {
      final istek = _istekHaritasi(s);
      final ok = await UrunService().decrementStocksIfSufficient(istek);
      if (ok && s.docId != null) {
        await _col.doc(s.docId!).update({'durum': SiparisDurumu.sevkiyat.name});
        counter++;

        // LOG
        await LogService.instance.logSiparis(
          action: 'siparis_sevkiyata_alindi',
          siparisId: s.docId!,
          meta: {'urunler': istek, 'mode': 'fifo'},
        );
      }
    }
    return counter;
  }

  /// ✅ Ekle + Tamamla: finans alanlarını garanti yaz (stokla oynamaz).
  Future<String> ekleVeTamamla(
    SiparisModel siparis, {
    DateTime? islemeTarihi,
  }) async {
    final map = {
      ...siparis.toMap(),
      'durum': SiparisDurumu.tamamlandi.name,
      'islemeTarihi': islemeTarihi != null
          ? Timestamp.fromDate(islemeTarihi)
          : FieldValue.serverTimestamp(),
    };
    map['netTutar'] ??= siparis.netToplam;
    map['kdvOrani'] ??= siparis.kdvOrani ?? 0.0;
    map['kdvTutar'] ??= siparis.kdvToplam;
    map['brutTutar'] ??= siparis.brutToplam;

    final ref = await _col.add(map);

    await LogService.instance.logSiparis(
      action: 'siparis_tamamlandi',
      siparisId: ref.id,
      meta: {'ekleVeTamamla': true},
    );

    return ref.id;
  }

  /// Tamamla: stokla oynamaz.
  Future<void> tamamla(String docId, {DateTime? islemeTarihi}) async {
    await _col.doc(docId).update({
      'durum': SiparisDurumu.tamamlandi.name,
      'islemeTarihi': islemeTarihi != null
          ? Timestamp.fromDate(islemeTarihi)
          : FieldValue.serverTimestamp(),
    });

    await LogService.instance.logSiparis(
      action: 'siparis_tamamlandi',
      siparisId: docId,
    );
  }

  Future<void> backfillIslemeTarihiTamamlananlar() async {
    final qs = await _col
        .where('durum', isEqualTo: SiparisDurumu.tamamlandi.name)
        .get();
    final batch = _db.batch();
    for (final d in qs.docs) {
      final m = d.data();
      if (m['islemeTarihi'] == null && m['tarih'] != null) {
        final ts = m['tarih'];
        DateTime? tarih;
        if (ts is Timestamp) {
          tarih = ts.toDate();
        } else if (ts is DateTime) {
          tarih = ts;
        } else if (ts is int) {
          tarih = DateTime.fromMillisecondsSinceEpoch(ts);
        }
        if (tarih != null) {
          batch.update(d.reference, {'islemeTarihi': Timestamp.fromDate(tarih)});
        }
      }
    }
    await batch.commit();
  }

  // ------------------ ÇEŞİTLİ ------------------

  Future<List<SiparisModel>> getirByDurumOnce(SiparisDurumu durum) async {
    final qs = await _col.where('durum', isEqualTo: durum.name).get();
    return qs.docs
        .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
        .toList();
  }

  Stream<List<SiparisModel>> musteriSiparisleriDinle(String musteriId) {
    return _col
        .where('musteri.id', isEqualTo: musteriId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((qs) => qs.docs
            .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
            .toList());
  }

  Future<List<SiparisModel>> getirByDurumVeMusteriOnce(
      SiparisDurumu durum, String musteriId) async {
    final qs = await _col
        .where('durum', isEqualTo: durum.name)
        .where('musteri.id', isEqualTo: musteriId)
        .orderBy('tarih')
        .get();
    return qs.docs
        .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
        .toList();
  }
}
