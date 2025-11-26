import 'dart:async';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

enum UretimSiralama { enCokEksik, urunAdinaGore, enEskiIstek }

extension UretimSiralamaExt on UretimSiralama {
  String get displayName {
    switch (this) {
      case UretimSiralama.enCokEksik: return 'En Çok Eksik Olan';
      case UretimSiralama.urunAdinaGore: return 'Ürün Adına Göre (A-Z)';
      case UretimSiralama.enEskiIstek: return 'En Eski İstek';
    }
  }
}

// --- MODELLER ---
class EksikIstek {
  final String siparisDocId;
  final DateTime siparisTarihi;
  final String musteriAdi;
  final int urunId;
  final String urunAdi;
  final String renk;
  final int toplamIstenen;
  final int eksikAdet;
  final String aciklama;

  const EksikIstek({
    required this.siparisDocId,
    required this.siparisTarihi,
    required this.musteriAdi,
    required this.urunId,
    required this.urunAdi,
    required this.renk,
    required this.toplamIstenen,
    required this.eksikAdet,
    required this.aciklama,
  });
}

class EksikGrup {
  final int urunId;
  final String urunAdi;
  final String renk;
  final int toplamEksik;
  final List<EksikIstek> firmalar;

  const EksikGrup({
    required this.urunId,
    required this.urunAdi,
    required this.renk,
    required this.toplamEksik,
    required this.firmalar,
  });
}

class UretimViewState {
  final bool loading;
  final String? error;
  final List<EksikGrup> eksikListe;
  final List<Urun> tumUrunler;

  const UretimViewState.loading() : loading = true, error = null, eksikListe = const [], tumUrunler = const [];
  const UretimViewState.error(this.error) : loading = false, eksikListe = const [], tumUrunler = const [];
  const UretimViewState.data({required this.eksikListe, required this.tumUrunler}) : loading = false, error = null;
}

// --- CONTROLLER ---
class UretimController {
  final SiparisService siparisServis;
  final UrunService urunServis;

  StreamSubscription? _subSips;
  StreamSubscription? _subUruns;
  final _out = StreamController<UretimViewState>.broadcast();

  List<SiparisModel> _cacheSips = const [];
  List<Urun> _cacheUruns = const [];

  Stream<UretimViewState> get stream => _out.stream;

  UretimController({required this.siparisServis, required this.urunServis});

  void init() {
    _out.add(const UretimViewState.loading());

    _subSips = siparisServis.dinle(sadeceDurum: SiparisDurumu.uretimde).listen(
      (sips) {
        sips.sort((a, b) => a.tarih.compareTo(b.tarih));
        _cacheSips = sips;
        _recompute();
      },
      onError: (e) => _out.add(UretimViewState.error("$e")),
    );

    _subUruns = urunServis.dinle().listen(
      (uruns) {
        _cacheUruns = uruns;
        _recompute();
      },
      onError: (e) => _out.add(UretimViewState.error("$e")),
    );
  }

  void _recompute() {
    if (_cacheSips.isEmpty && _cacheUruns.isEmpty) {
      _out.add(const UretimViewState.data(eksikListe: [], tumUrunler: []));
      return;
    }

    final stokMap = <int, int>{for (final u in _cacheUruns) u.id: u.adet};
    final temp = Map<int, int>.from(stokMap);
    final Map<String, List<EksikIstek>> gruplar = {};

    for (final sip in _cacheSips) {
      final musteriAdi = (sip.musteri.firmaAdi?.isNotEmpty == true)
          ? sip.musteri.firmaAdi!
          : (sip.musteri.yetkili ?? 'Müşteri');

      for (final su in sip.urunler) {
        final id = int.tryParse(su.id);
        if (id == null) continue;

        final varolan = temp[id] ?? 0;
        if (varolan >= su.adet) {
          temp[id] = varolan - su.adet;
        } else {
          final eksik = su.adet - varolan;
          temp[id] = 0;

          final item = EksikIstek(
            siparisDocId: sip.docId ?? '',
            siparisTarihi: sip.tarih,
            musteriAdi: musteriAdi,
            urunId: id,
            urunAdi: su.urunAdi,
            renk: su.renk ?? '',
            toplamIstenen: su.adet,
            eksikAdet: eksik,
            aciklama: "İstenen: ${su.adet} • Eksik: $eksik ${(sip.aciklama ?? '').isNotEmpty ? " • ${sip.aciklama}" : ""}",
          );

          final key = '$id|${item.renk}';
          (gruplar[key] ??= []).add(item);
        }
      }
    }

    final List<EksikGrup> eksikGruplar = gruplar.entries.map((e) {
      final parts = e.key.split('|');
      final urunId = int.tryParse(parts.first) ?? 0;
      final renk = parts.length > 1 ? parts[1] : '';
      final firmalar = e.value;
      final toplamEksik = firmalar.fold<int>(0, (sum, it) => sum + it.eksikAdet);
      final urunAdi = firmalar.isNotEmpty ? firmalar.first.urunAdi : 'Ürün';

      return EksikGrup(
        urunId: urunId,
        urunAdi: urunAdi,
        renk: renk,
        toplamEksik: toplamEksik,
        firmalar: firmalar..sort((a, b) => a.siparisTarihi.compareTo(b.siparisTarihi)),
      );
    }).toList();

    _out.add(UretimViewState.data(eksikListe: eksikGruplar, tumUrunler: _cacheUruns));
  }

  void dispose() {
    _subSips?.cancel();
    _subUruns?.cancel();
    _out.close();
  }
}