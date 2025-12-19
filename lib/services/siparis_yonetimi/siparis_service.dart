import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart'; // Stok kontrolü için (onayla metodu)
import 'package:capri/services/altyapi/log_service.dart';

class SiparisService {
  static final SiparisService _instance = SiparisService._internal();
  factory SiparisService() => _instance;
  SiparisService._internal();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('siparisler');

  // === Sipariş alan adları (sabitler) ===
  static const _fldDurum = 'durum';
  static const _fldSevkiyatHazir = 'sevkiyatHazir';
  // Diğer sevkiyat sabitleri artık SevkiyatService içinde kullanılacak.

  // ------------------ GENEL AKIŞLAR ------------------

  Stream<List<SiparisModel>> hepsiDinle() {
    return _col
        .orderBy('tarih', descending: true)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
              .toList(),
        );
  }

  Stream<List<SiparisModel>> dinle({SiparisDurumu? sadeceDurum}) {
    Query<Map<String, dynamic>> q = _col;
    if (sadeceDurum != null) {
      q = q.where('durum', isEqualTo: sadeceDurum.name);
    }
    q = q.orderBy('tarih', descending: true);
    return q.snapshots().map(
      (qs) => qs.docs
          .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
          .toList(),
    );
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
    Query<Map<String, dynamic>> q = _col.where(
      'durum',
      isEqualTo: SiparisDurumu.tamamlandi.name,
    );

    if (baslangic != null) {
      final start = DateTime(baslangic.year, baslangic.month, baslangic.day);
      q = q.where(
        'islemeTarihi',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (bitis != null) {
      final next = DateTime(
        bitis.year,
        bitis.month,
        bitis.day,
      ).add(const Duration(days: 1));
      q = q.where('islemeTarihi', isLessThan: Timestamp.fromDate(next));
    }

    q = q.orderBy('islemeTarihi', descending: false);
    return q.snapshots().map(
      (qs) => qs.docs
          .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
          .toList(),
    );
  }

  // ------------------ HELPER (SevkiyatService'e taşınmadığı için burada kaldı) ------------------

  /// Siparişteki ürünleri {urunId: toplamAdet} haritasına çevir.
  /// Not: Onay metodu hala bunu kullanıyor.
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
      meta: {'durum': siparis.durum.name, 'musteriId': siparis.musteri.id},
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

  Future<void> guncelleDurum(
    String docId,
    SiparisDurumu yeni, {
    bool islemeTarihiniAyarla = false,
    DateTime? islemeTarihi,
  }) async {
    // Sevkiyat ve Reddedildi durumları artık SevkiyatService'in sorumluluğunda olabilir.
    // Ancak tamamlandı ve diğer temel durumlar burada kalır.

    if (yeni == SiparisDurumu.tamamlandi) {
      final data = <String, dynamic>{'durum': yeni.name};
      if (islemeTarihiniAyarla) {
        data['islemeTarihi'] = islemeTarihi != null
            ? Timestamp.fromDate(islemeTarihi)
            : FieldValue.serverTimestamp();
      }
      await _col.doc(docId).update(data);

      await LogService.instance.logSiparis(
        action: 'siparis_tamamlandi',
        siparisId: docId,
        meta: {'islemeTarihi_set': islemeTarihiniAyarla},
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

  // ------------------ YENİ AKIŞ (ÖN ONAY - Stok kontrolü) ------------------

  /// ✅ Onay: stok DÜŞMEDEN kontrol edilir.
  /// - Yeterliyse: sevkiyatHazir:true, durum beklemede.
  /// - Yetersizse: durum uretimde, sevkiyatHazir:false.
  Future<bool> onayla(String docId) async {
    final ref = _col.doc(docId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Sipariş bulunamadı: $docId');
    final sip = SiparisModel.fromMap(snap.data()!).copyWith(docId: snap.id);

    final istek = _istekHaritasi(sip);
    // UrunService'den kontrol edilir, stok düşülmez.
    final stokYeterli = await UrunService().stocksSufficient(istek);

    final updates = <String, dynamic>{
      _fldSevkiyatHazir: stokYeterli,
      _fldDurum: stokYeterli
          ? SiparisDurumu.beklemede.name
          : SiparisDurumu.uretimde.name,
      'onayAt': FieldValue.serverTimestamp(), // bilgi amaçlı
    };

    await ref.update(updates);

    await LogService.instance.logSiparis(
      action: stokYeterli
          ? 'siparis_onaylandi_stok_yeterli'
          : 'siparis_onaylandi_stok_yetersiz',
      siparisId: docId,
      meta: stokYeterli ? {'urunler': istek} : null,
    );

    return stokYeterli;
  }

  /// ♻️ Geriye uyum: Eski metot artık sadece ONAY davranışı yapar (stok düşmez).
  Future<bool> onaylaVeStokAyir(String docId) => onayla(docId);

  // ------------------ DİĞERLERİ (SevkiyatService'e taşınanlar silindi) ------------------

  // sevkiyataOnayla, sevkiyataGecir, allocateFIFOAcrossProduction ve reddetVeStokIade
  // metotları SevkiyatService'e taşınmıştır.

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
          batch.update(d.reference, {
            'islemeTarihi': Timestamp.fromDate(tarih),
          });
        }
      }
    }
    await batch.commit();
  }

  // ------------------ ÜRETİM İLERLEMESİ ------------------

  /// 🔹 Belirli bir siparişteki belirli bir ürünün üretilen miktarını günceller.
  ///    Ürün stoğunu artırmaz (stoğa ekleme ayrı yerde yapılır).
  Future<void> guncelleUretilenAdet(
    String siparisDocId,
    String urunId,
    int uretilenAdet,
  ) async {
    final snap = await _col.doc(siparisDocId).get();
    if (!snap.exists) {
      throw StateError('Sipariş bulunamadı: $siparisDocId');
    }
    final sip = SiparisModel.fromMap(snap.data()!).copyWith(docId: snap.id);

    final updatedUrunler = sip.urunler.map((su) {
      if (su.id == urunId) {
        return su.copyWith(uretilenAdet: (su.uretilenAdet ?? 0) + uretilenAdet);
      }
      return su;
    }).toList();

    await _col.doc(siparisDocId).update({
      'urunler': updatedUrunler.map((e) => e.toMap()).toList(),
    });

    await LogService.instance.logSiparis(
      action: 'siparis_urun_uretildi',
      siparisId: siparisDocId,
      meta: {'urunId': urunId, 'uretilenAdet': uretilenAdet},
    );
  }

  /// 🔹 Üretim ilerlemesini transaction ile günceller.
  ///    NOT: Artık burada otomatik sevkiyat veya stok düşümü YOK.
  ///    Tüm kalemler tamamlanmışsa `true` döner, ancak durum/stok değiştirmez.
  Future<bool> uretilenMiktariGuncelle(
    String siparisDocId,
    String urunId,
    int uretilenAdet,
  ) async {
    final docRef = _col.doc(siparisDocId);

    return FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final docSnapshot = await transaction.get(docRef);

      if (!docSnapshot.exists) {
        throw Exception("Sipariş belgesi bulunamadı!");
      }

      final siparis = SiparisModel.fromMap(docSnapshot.data()!);

      // İlgili ürünü bul
      final urunIndex = siparis.urunler.indexWhere((u) => u.id == urunId);
      if (urunIndex == -1) {
        throw Exception("Sipariş içinde ürün bulunamadı!");
      }

      final guncellenecekUrun = siparis.urunler[urunIndex];
      final yeniUretilenAdet =
          (guncellenecekUrun.uretilenAdet ?? 0) + uretilenAdet;
      final toplamAdet = guncellenecekUrun.adet;

      // Üretilen adet istenen adeti geçemez.
      final guncelUrun = guncellenecekUrun.copyWith(
        uretilenAdet: min(yeniUretilenAdet, toplamAdet),
      );

      // Yeni üretilen adetle ürün listesini güncelle
      final guncelUrunListesi = List.of(siparis.urunler);
      guncelUrunListesi[urunIndex] = guncelUrun;

      // Siparişi güncelle
      transaction.update(docRef, {
        'urunler': guncelUrunListesi.map((u) => u.toMap()).toList(),
      });

      // Tamamı sevke hazır mı? (yalnızca bilgi amaçlı dönüş)
      final hepsiHazir = guncelUrunListesi.every(
        (urun) => (urun.uretilenAdet ?? 0) >= urun.adet,
      );

      // OTOMATİK sevkiyata geçiş veya stok düşümü YOK.
      return hepsiHazir;
    });
  }

  // ------------------ ÇEŞİTLİ ------------------

  Future<List<SiparisModel>> getirByDurumOnce(SiparisDurumu durum) async {
    final qs = await _col.where('durum', isEqualTo: durum.name).get();
    return qs.docs
        .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
        .toList();
  }

  Stream<List<SiparisModel>> musteriSiparisleriDinle(String musteriId) {
    Set<String> aranacakIdler = {musteriId};

    try {
      // Eğer ID sayıya çevrilebiliyorsa, sıfırları atılmış halini de ekle
      // Örnek: "000024" -> 24 -> "24"
      final sadeId = int.parse(musteriId).toString();
      aranacakIdler.add(sadeId);
    } catch (_) {
      // ID sadece harflerden oluşuyorsa (örn: "ABC") burayı pas geç
    }
    return _col
        .where('musteri.id', whereIn: aranacakIdler.toList())
        .orderBy('tarih', descending: true)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => SiparisModel.fromMap(d.data()).copyWith(docId: d.id))
              .toList(),
        );
  }

  Future<List<SiparisModel>> getirByDurumVeMusteriOnce(
    SiparisDurumu durum,
    String musteriId,
  ) async {
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
