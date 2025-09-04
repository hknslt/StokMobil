// lib/services/istatistik_servisi.dart
import 'package:capri/core/models/kazanc_verisi.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/siparis_service.dart';

class IstatistikServisi {
  IstatistikServisi._();
  static final IstatistikServisi instance = IstatistikServisi._();

  final _svc = SiparisService();

  /// ✅ Günlük KAZANÇ akımı (yalnızca 'tamamlandi')
  Stream<List<KazancVerisi>> gunlukKazancAkim({required DateTime baslangic}) {
    final start = DateTime(baslangic.year, baslangic.month, baslangic.day);
    return _svc.tamamlananDinle(baslangic: start).map((siparisler) {
      final end = DateTime.now();
      final map = <DateTime, double>{};

      for (final s in siparisler) {
        final dt = (s.islemeTarihi ?? s.tarih);
        if (dt.isBefore(start)) continue;
        final key = DateTime(dt.year, dt.month, dt.day);
        map[key] = (map[key] ?? 0) + (s.toplamTutar);
      }

      // Eksik günleri 0 ile doldur ve sıralı liste dön
      final filled = <KazancVerisi>[];
      for (
        DateTime d = start;
        !d.isAfter(DateTime(end.year, end.month, end.day));
        d = d.add(const Duration(days: 1))
      ) {
        final key = DateTime(d.year, d.month, d.day);
        filled.add(KazancVerisi(tarih: key, kazanc: map[key] ?? 0));
      }
      return filled;
    });
  }

  /// ✅ Günlük TAMAMLANAN SİPARİŞ SAYISI akımı
  Stream<Map<DateTime, int>> gunlukSiparisSayisiAkim({
    required DateTime baslangic,
  }) {
    final start = DateTime(baslangic.year, baslangic.month, baslangic.day);
    return _svc.tamamlananDinle(baslangic: start).map((siparisler) {
      final end = DateTime.now();
      final map = <DateTime, int>{};

      for (final s in siparisler) {
        final dt = (s.islemeTarihi ?? s.tarih);
        if (dt.isBefore(start)) continue;
        final key = DateTime(dt.year, dt.month, dt.day);
        map[key] = (map[key] ?? 0) + 1;
      }

      // Eksik günleri 0 ile doldur
      final out = <DateTime, int>{};
      for (
        DateTime d = start;
        !d.isAfter(DateTime(end.year, end.month, end.day));
        d = d.add(const Duration(days: 1))
      ) {
        final key = DateTime(d.year, d.month, d.day);
        out[key] = map[key] ?? 0;
      }
      return out;
    });
  }

  Stream<List<Map<String, dynamic>>> enCokSatanUrunlerAkim({
    required DateTime baslangic,
    int? limit,
  }) {
    final start = DateTime(baslangic.year, baslangic.month, baslangic.day);
    return _svc.tamamlananDinle(baslangic: start).map((siparisler) {
      final toplam = <String, Map<String, dynamic>>{};

      for (final s in siparisler) {
        final dt = (s.islemeTarihi ?? s.tarih);
        if (dt.isBefore(start)) continue;

        final urunler = s.urunler ?? [];
        for (final u in urunler) {
          final ad = (u.urunAdi ?? '').trim();
          if (ad.isEmpty) continue;

          final adet = u.adet ?? 0;
          final ciro = (u.birimFiyat ?? 0) * adet;

          final prev = toplam[ad];
          if (prev == null) {
            toplam[ad] = {'urunAdi': ad, 'adet': adet, 'ciro': ciro};
          } else {
            prev['adet'] = (prev['adet'] as int) + adet;
            prev['ciro'] = (prev['ciro'] as num).toDouble() + ciro;
          }
        }
      }

      var list = toplam.values.toList();
      list.sort((a, b) => (b['adet'] as int).compareTo(a['adet'] as int));
      if (limit != null && list.length > limit) {
        list = list.sublist(0, limit);
      }
      return list;
    });
  }
}
