// lib/services/urun_service.dart
import 'dart:io';

import 'package:capri/services/fiyat_listesi_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/models/urun_model.dart';
import 'package:capri/services/log_service.dart';

class UrunService {
  static final UrunService _instance = UrunService._internal();
  factory UrunService() => _instance;

  UrunService._internal();

  // ---------- Firestore / Storage ----------
  final _col = FirebaseFirestore.instance.collection('urunler');
  final _storage = FirebaseStorage.instance;

  Stream<List<Urun>> dinle() {
    return _col
        .orderBy('urunAdi')
        .snapshots()
        .map((qs) => qs.docs.map((d) => Urun.fromFirestore(d)).toList());
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

  // ---------------------- RESİM YÜKLEME YARDIMCILARI ----------------------

  Future<String> _uploadOne({
    required String docId,
    required File file,
    required String fileName,
  }) async {
    final ref = _storage.ref('urunler/$docId/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Çoklu resmi yükler, kapak ve liste URL'lerini döndürür.
  Future<({String? coverUrl, List<String> urls})> _uploadImagesForDoc({
    required String docId,
    required List<File> localFiles,
    String? coverLocalPath,
  }) async {
    if (localFiles.isEmpty) return (coverUrl: null, urls: const <String>[]);

    final urls = <String>[];
    String? coverUrl;

    for (final f in localFiles) {
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}';
      final url = await _uploadOne(docId: docId, file: f, fileName: name);
      urls.add(url);
      if (coverLocalPath != null && f.path == coverLocalPath) {
        coverUrl = url;
      }
    }
    coverUrl ??= urls.first;
    return (coverUrl: coverUrl, urls: urls);
  }

  // --------------------------- CRUD ---------------------------

  /// Ürün ekler. (Opsiyonel) [localFiles] gönderirsen resimler Storage'a yüklenir ve
  /// oluşan URL'ler Firestore'a yazılır. [coverLocalPath] kapak olarak işaretlenecek yerel path.
  Future<void> ekle(
    Urun urun, {
    List<File> localFiles = const [],
    String? coverLocalPath,
  }) async {
    final id = urun.id == 0 ? await _yeniNumericId() : urun.id;

    // 1) Belgeyi (resimsiz) oluştur ve docId al
    final ref = _col.doc();
    await ref.set(
      urun.copyWith(id: id, resimYollari: [], kapakResimYolu: null).toMap(),
    );

    // 2) Resimleri yükle → URL'leri yaz
    if (localFiles.isNotEmpty) {
      final uploaded = await _uploadImagesForDoc(
        docId: ref.id,
        localFiles: localFiles,
        coverLocalPath: coverLocalPath,
      );
      await ref.update({
        'resimYollari': uploaded.urls,
        'kapakResimYolu': uploaded.coverUrl,
      });
    }

    // LOG
    await LogService.instance.logUrun(
      action: 'urun_eklendi',
      urunDocId: ref.id,
      urunId: id,
      urunAdi: urun.urunAdi,
      meta: {'renk': urun.renk, 'adet': urun.adet},
    );

    await FiyatListesiService.instance.yeniUrunTumListelereSifirEkle(id);
  }

  /// Ürün günceller. Metin/sayı alanlarını [urun] içinden alır.
  /// (Opsiyonel) [newLocalFiles] gönderirsen yeni resimler yüklenir ve
  /// Firestore'daki `resimYollari` dizisine eklenir. [urlsToDelete] verilirse Storage'tan silinir.
  Future<void> guncelle(
    String docId,
    Urun urun, {
    List<File> newLocalFiles = const [],
    List<String> urlsToDelete = const [],
  }) async {
    // 1) Eski resimleri sil
    if (urlsToDelete.isNotEmpty) {
      for (final url in urlsToDelete) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          print('Silme hatası: $e');
        }
      }
    }

    // 2) Yeni resimleri yükle ve URL'leri al
    List<String> newUrls = [];
    String? newCoverUrl;

    if (newLocalFiles.isNotEmpty) {
      final uploaded = await _uploadImagesForDoc(
        docId: docId,
        localFiles: newLocalFiles,
        coverLocalPath: urun.kapakResimYolu,
      );
      newUrls = uploaded.urls;
      newCoverUrl = uploaded.coverUrl;
    }

    // 3) Firestore'daki resim yolları listesini güncelle
    final existingUrls = urun.resimYollari ?? [];
    final updatedUrls =
        existingUrls.where((url) => !urlsToDelete.contains(url)).toList()
          ..addAll(newUrls);

    // 4) Firestore belgesini güncelle
    await _col.doc(docId).update({
      ...urun.toMap(),
      'resimYollari': updatedUrls,
      'kapakResimYolu': newCoverUrl ?? urun.kapakResimYolu,
    });

    // LOG
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

    // Firestore'dan belgeyi sil
    await _col.doc(docId).delete();

    // Firebase Storage'daki klasörü ve tüm resimleri sil
    try {
      final folderRef = _storage.ref('urunler/$docId');
      final list = await folderRef.listAll();
      for (final i in list.items) {
        await i.delete();
      }
      for (final p in list.prefixes) {
        await p.delete();
      }
    } catch (e) {
      print('Storage dosya silme hatası: $e');
    }

    // LOG
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

      // Transaction sonrası logla
      Future(() async {
        await LogService.instance.logUrun(
          action: delta >= 0 ? 'stok_eklendi' : 'stok_azaltildi',
          urunDocId: docId,
          urunId: urunId,
          urunAdi: urunAdi,
          meta: {'delta': delta, 'oncekiAdet': cur, 'yeniAdet': yeni},
        );
      });
    });
  }

  // ---------- Stok yardımcıları ----------
  Future<Map<int, int>> getStocksByNumericIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final chunks = <List<int>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
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

  /// 🔎 YENİ: Sadece kontrol — tüm istekler mevcut stokla karşılanabiliyor mu?
  Future<bool> stocksSufficient(Map<int, int> istek) async {
    if (istek.isEmpty) return true;
    final stokHarita = await getStocksByNumericIds(istek.keys.toList());
    for (final entry in istek.entries) {
      final mevcut = stokHarita[entry.key] ?? 0;
      if (mevcut < entry.value) return false;
    }
    return true;
  }

  /// Hepsi yeterliyse tek transaction içinde stokları düş
  Future<bool> decrementStocksIfSufficient(Map<int, int> istek) async {
    if (istek.isEmpty) return true;

    final refs = <int, DocumentReference<Map<String, dynamic>>>{};
    final ids = istek.keys.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
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

  Future<void> incrementStocksByNumericIds(Map<int, int> eklemeler) async {
    if (eklemeler.isEmpty) return;

    final refs = <int, DocumentReference<Map<String, dynamic>>>{};
    final ids = eklemeler.keys.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final qs = await _col.where('id', whereIn: chunk).get();
      for (final d in qs.docs) {
        final id = (d.data()['id'] as num).toInt();
        refs[id] = d.reference;
      }
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      for (final e in eklemeler.entries) {
        final ref = refs[e.key];
        if (ref == null) continue;
        final snap = await tx.get(ref);
        if (!snap.exists) continue;
        final cur = (snap.data()?['adet'] as num?)?.toInt() ?? 0;
        tx.update(ref, {'adet': cur + e.value});
      }
    });
  }
}
