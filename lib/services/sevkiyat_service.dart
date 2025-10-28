import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/log_service.dart';
import 'package:collection/collection.dart';

class SevkiyatService {
  static final SevkiyatService _instance = SevkiyatService._internal();
  factory SevkiyatService() => _instance;
  SevkiyatService._internal();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _siparisCol =>
      _db.collection('siparisler');
  CollectionReference<Map<String, dynamic>> get _urunCol =>
      _db.collection('urunler');

  static const _fldDurum = 'durum';
  static const _fldSevkiyatHazir = 'sevkiyatHazir';
  static const _fldSevkiyatOnayAt = 'sevkiyatOnayAt';
  static const _fldStokDusumYapildi = 'stokDusumYapildi';
  static const _fldIadeYapildiAt = 'iadeYapildiAt';

  Map<int, int> _istekHaritasi(SiparisModel s) {
    final map = <int, int>{};
    for (final su in s.urunler) {
      final id = int.tryParse(su.id);
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + su.adet;
    }
    return map;
  }

  Future<void> sevkiyatUrunleriniGuncelle(
    String docId,
    List<SiparisUrunModel> yeniUrunler,
  ) async {
    final sipRef = _siparisCol.doc(docId);

    await _db.runTransaction<void>((tx) async {
      final sipSnap = await tx.get(sipRef);
      if (!sipSnap.exists) throw StateError('Sipariş bulunamadı: $docId');

      final mevcutSiparis = SiparisModel.fromMap(
        sipSnap.data()!,
      ).copyWith(docId: sipSnap.id);

      final mevcutUrunMap = {for (var u in mevcutSiparis.urunler) u.id: u};
      final yeniUrunMap = {for (var u in yeniUrunler) u.id: u};
      final stokFarklari = <int, int>{};

      for (final yeniUrunId in yeniUrunMap.keys) {
        final urunIdInt = int.tryParse(yeniUrunId);
        if (urunIdInt == null) continue;

        final yeniAdet = yeniUrunMap[yeniUrunId]!.adet;
        final mevcutAdet = mevcutUrunMap[yeniUrunId]?.adet ?? 0;
        final fark = yeniAdet - mevcutAdet;

        if (fark != 0) {
          stokFarklari[urunIdInt] = fark;
        }
        mevcutUrunMap.remove(yeniUrunId);
      }

      for (final mevcutUrun in mevcutUrunMap.values) {
        final urunIdInt = int.tryParse(mevcutUrun.id);
        if (urunIdInt == null) continue;
        stokFarklari[urunIdInt] = 0 - mevcutUrun.adet;
      }

      if (stokFarklari.isNotEmpty) {
        final urunIdList = stokFarklari.keys.toList();
        final urunRefs = <int, DocumentReference>{};

        for (final chunk in urunIdList.slices(10)) {
          final qs = await _urunCol.where('id', whereIn: chunk).get();
          for (final doc in qs.docs) {
            final data = doc.data();
            final id = (data['id'] as num).toInt();
            urunRefs[id] = doc.reference;
          }
        }

        for (final entry in stokFarklari.entries) {
          final urunId = entry.key;
          final farkAdet = entry.value;
          final ref = urunRefs[urunId];

          if (ref == null)
            throw Exception("Stokta bulunamayan ürün ID: $urunId");

          final stokSnap = await tx.get(ref);
          if (!stokSnap.exists)
            throw Exception("Stok belgesi bulunamadı: ID $urunId");

          // 💡 DÜZELTİLDİ: stokSnap.data() bir Map'e dönüştürülüyor.
          final stokData = stokSnap.data() as Map<String, dynamic>?;
          final mevcutMiktar = (stokData?['adet'] as num?)?.toInt() ?? 0;
          final yeniMiktar = mevcutMiktar - farkAdet;

          if (yeniMiktar < 0) {
            throw Exception("Stok yetersiz! Ürün ID: $urunId");
          }
          tx.update(ref, {'adet': yeniMiktar});
        }
      }

      final guncelSiparis = mevcutSiparis.copyWith(
        urunler: yeniUrunler,
        netTutar: null,
        kdvTutar: null,
        brutTutar: null,
      );
      tx.update(sipRef, guncelSiparis.toMap());

      await LogService.instance.logSiparis(
        action: 'sevkiyat_urun_guncellendi_ve_stok_ayari',
        siparisId: docId,
        meta: {'farklar': stokFarklari},
      );
    });
  }

  Future<bool> sevkiyataOnayla(String docId) async {
    final ref = _siparisCol.doc(docId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Sipariş bulunamadı: $docId');
    final data = snap.data()!;
    final durum = data[_fldDurum] as String?;
    final sevkiyatOnayAt = data[_fldSevkiyatOnayAt];
    final stokDusumYapildi = (data[_fldStokDusumYapildi] as bool?) ?? false;
    if (sevkiyatOnayAt != null ||
        stokDusumYapildi == true ||
        durum == SiparisDurumu.sevkiyat.name ||
        durum == SiparisDurumu.tamamlandi.name) {
      return true;
    }
    final sip = SiparisModel.fromMap(data).copyWith(docId: snap.id);
    final istek = _istekHaritasi(sip);
    final ok = await UrunService().decrementStocksIfSufficient(istek);
    if (!ok) {
      await ref.update({
        _fldDurum: SiparisDurumu.uretimde.name,
        _fldSevkiyatHazir: false,
      });
      await LogService.instance.logSiparis(
        action: 'sevkiyat_onayi_stok_yetersiz',
        siparisId: docId,
      );
      return false;
    }
    await ref.update({
      _fldDurum: SiparisDurumu.sevkiyat.name,
      _fldSevkiyatHazir: false,
      _fldSevkiyatOnayAt: FieldValue.serverTimestamp(),
      _fldStokDusumYapildi: true,
    });
    for (final su in sip.urunler) {
      final uid = int.tryParse(su.id);
      await LogService.instance.logUrun(
        action: 'stok_azaltildi',
        urunDocId: null,
        urunId: uid,
        urunAdi: su.urunAdi,
        meta: {'adet': su.adet, 'reason': 'sevkiyat_onayi', 'siparisId': docId},
      );
    }
    await LogService.instance.logSiparis(
      action: 'sevkiyat_onayi_basarili',
      siparisId: docId,
      meta: {'urunler': istek},
    );
    return true;
  }

  Future<void> reddetVeStokIade(String docId) async {
    final sipRef = _siparisCol.doc(docId);
    await _db.runTransaction<void>((tx) async {
      final sipSnap = await tx.get(sipRef);
      if (!sipSnap.exists) throw StateError('Sipariş bulunamadı: $docId');
      final data = sipSnap.data()!;
      final durum = data[_fldDurum] as String?;
      final iadeYapildiAt = data[_fldIadeYapildiAt];
      final stokDusumYapildi = (data[_fldStokDusumYapildi] as bool?) ?? false;
      if (durum == SiparisDurumu.reddedildi.name && iadeYapildiAt != null) {
        return;
      }
      if (durum == SiparisDurumu.sevkiyat.name &&
          stokDusumYapildi &&
          iadeYapildiAt == null) {
        final sip = SiparisModel.fromMap(data).copyWith(docId: sipSnap.id);
        final istek = _istekHaritasi(sip);
        final urunIdList = istek.keys.toList();
        final urunRefs = <int, DocumentReference>{};
        for (final chunk in urunIdList.slices(10)) {
          final qs = await _urunCol.where('id', whereIn: chunk).get();
          for (final doc in qs.docs) {
            final data = doc.data();
            final id = (data['id'] as num).toInt();
            urunRefs[id] = doc.reference;
          }
        }
        for (final e in istek.entries) {
          final ref = urunRefs[e.key];
          if (ref == null) continue;
          final stokSnap = await tx.get(ref);
          if (!stokSnap.exists) continue;

          // 💡 DÜZELTİLDİ: stokSnap.data() bir Map'e dönüştürülüyor.
          final stokData = stokSnap.data() as Map<String, dynamic>?;
          final mevcut = (stokData?['adet'] as num?)?.toInt() ?? 0;
          tx.update(ref, {'adet': mevcut + e.value});
        }
        tx.update(sipRef, {_fldIadeYapildiAt: FieldValue.serverTimestamp()});
      }
      tx.update(sipRef, {
        _fldDurum: SiparisDurumu.reddedildi.name,
        _fldSevkiyatHazir: false,
      });
    });
    await LogService.instance.logSiparis(
      action: 'siparis_reddedildi_tx',
      siparisId: docId,
    );
  }
}
