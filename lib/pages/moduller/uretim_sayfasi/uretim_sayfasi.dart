import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

// YENİ EKLENDİ: Sıralama seçenekleri için enum
enum UretimSiralama { enCokEksik, urunAdinaGore, enEskiIstek }

extension UretimSiralamaExt on UretimSiralama {
  String get displayName {
    switch (this) {
      case UretimSiralama.enCokEksik:
        return 'En Çok Eksik Olan';
      case UretimSiralama.urunAdinaGore:
        return 'Ürün Adına Göre (A-Z)';
      case UretimSiralama.enEskiIstek:
        return 'En Eski İstek';
    }
  }
}

String fmtDate(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

/// Alt kırılım: firma bazlı eksik kalem (bilgilendirme için)
class EksikIstek {
  final String siparisDocId;
  final DateTime siparisTarihi;
  final String musteriAdi;
  final int urunId;
  final String urunAdi;
  final String renk; // '' olabilir
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

/// Üst grup: ürün bazında toplanmış eksikler
class EksikGrup {
  final int urunId;
  final String urunAdi;
  final String renk; // '' olabilir
  final int toplamEksik;
  final List<EksikIstek> firmalar; // sadece bilgi amaçlı liste

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

  const UretimViewState.loading()
    : loading = true,
      error = null,
      eksikListe = const [],
      tumUrunler = const [];

  const UretimViewState.error(this.error)
    : loading = false,
      eksikListe = const [],
      tumUrunler = const [];

  const UretimViewState.data({
    required this.eksikListe,
    required this.tumUrunler,
  }) : loading = false,
       error = null;
}

/// Controller: iki servisi dinler, tek akış üretir
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

    _subSips = siparisServis
        .dinle(sadeceDurum: SiparisDurumu.uretimde)
        .listen(
          (sips) {
            // FIFO sıralama
            sips.sort((a, b) => a.tarih.compareTo(b.tarih));
            _cacheSips = sips;
            _recompute();
          },
          onError: (e) {
            _out.add(UretimViewState.error("$e"));
          },
        );

    _subUruns = urunServis.dinle().listen(
      (uruns) {
        _cacheUruns = uruns;
        _recompute();
      },
      onError: (e) {
        _out.add(UretimViewState.error("$e"));
      },
    );
  }

  void _recompute() {
    if (_cacheSips.isEmpty && _cacheUruns.isEmpty) {
      _out.add(const UretimViewState.data(eksikListe: [], tumUrunler: []));
      return;
    }

    // Ürün id -> stok
    final stokMap = <int, int>{for (final u in _cacheUruns) u.id: u.adet};
    final temp = Map<int, int>.from(stokMap);

    // Grup key: "$urunId|$renk"
    final Map<String, List<EksikIstek>> gruplar = {};

    for (final sip in _cacheSips) {
      final musteriAdi =
          (sip.musteri.firmaAdi != null && sip.musteri.firmaAdi!.isNotEmpty)
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

          final renk = (su.renk ?? '');
          final acik = (sip.aciklama ?? '');
          final aciklama =
              "Sipariş: ${fmtDate(sip.tarih)} • İstenen: ${su.adet} • Eksik: $eksik"
              "${acik.isNotEmpty ? " • $acik" : ""}";

          final item = EksikIstek(
            siparisDocId: sip.docId ?? '',
            siparisTarihi: sip.tarih,
            musteriAdi: musteriAdi,
            urunId: id,
            urunAdi: su.urunAdi,
            renk: renk,
            toplamIstenen: su.adet,
            eksikAdet: eksik,
            aciklama: aciklama,
          );

          final key = '$id|$renk';
          (gruplar[key] ??= <EksikIstek>[]).add(item);
        }
      }
    }

    // Grupları oluştur (Sıralama UI tarafında yapılacak)
    final List<EksikGrup> eksikGruplar = gruplar.entries.map((e) {
      final parts = e.key.split('|');
      final urunId = int.tryParse(parts.first) ?? 0;
      final renk = parts.length > 1 ? parts[1] : '';
      final firmalar = e.value;
      final toplamEksik = firmalar.fold<int>(
        0,
        (sum, it) => sum + it.eksikAdet,
      );
      final urunAdi = firmalar.isNotEmpty ? firmalar.first.urunAdi : 'Ürün';

      return EksikGrup(
        urunId: urunId,
        urunAdi: urunAdi,
        renk: renk,
        toplamEksik: toplamEksik,
        firmalar: firmalar
          ..sort((a, b) => a.siparisTarihi.compareTo(b.siparisTarihi)), // FIFO
      );
    }).toList();

    _out.add(
      UretimViewState.data(eksikListe: eksikGruplar, tumUrunler: _cacheUruns),
    );
  }

  void dispose() async {
    await _subSips?.cancel();
    await _subUruns?.cancel();
    await _out.close();
  }
}

class UretimSayfasi extends StatefulWidget {
  const UretimSayfasi({super.key});
  @override
  State<UretimSayfasi> createState() => _UretimSayfasiState();
}

class _UretimSayfasiState extends State<UretimSayfasi>
    with AutomaticKeepAliveClientMixin {
  final _controller = UretimController(
    siparisServis: SiparisService(),
    urunServis: UrunService(),
  );

  // --- YENİ EKLENEN STATE'LER ---
  final _aramaController = TextEditingController();
  String _aramaMetni = '';
  UretimSiralama _siralama = UretimSiralama.enCokEksik; // Varsayılan sıralama

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.init();
    // Arama metni değiştikçe UI'ı güncelle
    _aramaController.addListener(() {
      setState(() {
        _aramaMetni = _aramaController.text;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _aramaController.dispose(); // Controller'ı temizle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Üretim"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Renkler.anaMavi, Renkler.kahveTon.withOpacity(.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<UretimViewState>(
        stream: _controller.stream,
        builder: (context, snap) {
          final st = snap.data;

          if (st == null || st.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (st.error != null) {
            return Center(child: Text('Hata: ${st.error}'));
          }
          if (st.eksikListe.isEmpty) {
            return const Center(child: Text("Şu anda bekleyen istek yok."));
          }

          // --- ARAMA VE SIRALAMA MANTIĞINI UYGULA ---
          final sorgu = _aramaMetni.trim().toLowerCase();
          List<EksikGrup> gorunenListe = st.eksikListe;

          // 1. Arama Filtresi
          if (sorgu.isNotEmpty) {
            gorunenListe = gorunenListe.where((grup) {
              // Ürün adı, renk veya müşteri adında arama yap
              final urunAdiMatch = grup.urunAdi.toLowerCase().contains(sorgu);
              final renkMatch = grup.renk.toLowerCase().contains(sorgu);
              final musteriMatch = grup.firmalar.any(
                (f) => f.musteriAdi.toLowerCase().contains(sorgu),
              );
              return urunAdiMatch || renkMatch || musteriMatch;
            }).toList();
          }

          // 2. Sıralama
          gorunenListe.sort((a, b) {
            switch (_siralama) {
              case UretimSiralama.urunAdinaGore:
                return a.urunAdi.compareTo(b.urunAdi);
              case UretimSiralama.enEskiIstek:
                // Gruplar içindeki firmalar zaten tarihe göre sıralı
                final tarihA = a.firmalar.first.siparisTarihi;
                final tarihB = b.firmalar.first.siparisTarihi;
                return tarihA.compareTo(tarihB);
              case UretimSiralama.enCokEksik:
              default:
                final cmp = b.toplamEksik.compareTo(a.toplamEksik);
                if (cmp != 0) return cmp;
                return a.urunAdi.compareTo(b.urunAdi);
            }
          });
          // --- MANTIK SONU ---

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ARAMA VE SIRALAMA UI BÖLÜMÜ ---
                TextField(
                  controller: _aramaController,
                  decoration: InputDecoration(
                    labelText: 'Ürün veya Müşteri Ara',
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _aramaMetni.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _aramaController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "İstek Listesi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<UretimSiralama>(
                      value: _siralama,
                      onChanged: (UretimSiralama? newValue) {
                        if (newValue != null) {
                          setState(() => _siralama = newValue);
                        }
                      },
                      items: UretimSiralama.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.displayName),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // --- UI BÖLÜMÜ SONU ---
                if (gorunenListe.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text("Arama kriterlerine uyan sonuç bulunamadı."),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      key: const PageStorageKey('uretim-istek-list'),
                      padding: const EdgeInsets.only(bottom: 96, top: 4),
                      itemCount: gorunenListe.length,
                      itemBuilder: (context, i) {
                        final grp = gorunenListe[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey<String>(
                                'exp-${grp.urunId}-${grp.renk}',
                              ),
                              maintainState: true,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              initiallyExpanded: false,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${grp.urunAdi} | ${grp.renk.isEmpty ? '-' : grp.renk}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Toplam eksik: ${grp.toplamEksik}",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text("Stok Ekle"),
                                    style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all<Color>(
                                            Renkler.kahveTon,
                                          ),
                                    ),
                                    onPressed: () => _grupStokEkleDialog(
                                      context,
                                      grp,
                                      st.tumUrunler,
                                    ),
                                  ),
                                ],
                              ),
                              children: grp.firmalar
                                  .map(
                                    (it) => ListTile(
                                      dense: true,
                                      title: Text(
                                        "Firma: ${it.musteriAdi}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        it.aciklama,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (ctx) => FloatingActionButton.extended(
          onPressed: () => _stokEkleDialog(ctx),
          tooltip: "Stok Ekle",
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Yeni Stok",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Renkler.kahveTon,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ---- Dialog: Grup için Stok Ekle (ÜRÜN BAZLI) ----
  Future<void> _grupStokEkleDialog(
    BuildContext parentCtx,
    EksikGrup grp,
    List<Urun> tumUrunler,
  ) async {
    final adetCtrl = TextEditingController();
    await showDialog(
      context: parentCtx,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        bool isBusy = false;

        return StatefulBuilder(
          builder: (localCtx, setLocal) => AlertDialog(
            title: Text("${grp.urunAdi} için Stok Ekle"),
            content: TextField(
              controller: adetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Eklenecek Adet (Toplam Eksik: ${grp.toplamEksik})",
                labelStyle: TextStyle(color: Renkler.kahveTon),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                ),
              ),
              enabled: !isBusy,
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => nav.pop(),
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Renkler.kahveTon),
                ),
              ),
              ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        final ek = int.tryParse(adetCtrl.text.trim()) ?? 0;
                        if (ek <= 0) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentCtx).showSnackBar(
                            const SnackBar(
                              content: Text("Geçerli bir adet girin."),
                            ),
                          );
                          return;
                        }

                        setLocal(() => isBusy = true);
                        try {
                          // İlgili ürünü bul
                          final urun = tumUrunler.firstWhereOrNull(
                            (u) => u.id == grp.urunId,
                          );
                          if (urun == null || urun.docId == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              const SnackBar(content: Text("Ürün bulunamadı.")),
                            );
                            return;
                          }

                          // Sadece STOĞU artır — sipariş durumlarına OTOMATİK dokunma!
                          await UrunService().adetArtir(urun.docId!, ek);

                          if (parentCtx.mounted) {
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Stoğa eklendi: ${grp.urunAdi}"
                                  "${grp.renk.isNotEmpty ? " (${grp.renk})" : ""} → +$ek adet. "
                                  "Sevkiyat için Siparişler sayfasında ilgili siparişe Onay verin.",
                                ),
                              ),
                            );
                          }
                          nav.pop();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentCtx).showSnackBar(
                            SnackBar(content: Text("İşlem başarısız: $e")),
                          );
                        } finally {
                          if (localCtx.mounted) setLocal(() => isBusy = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Renkler.kahveTon,
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Ekle", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Dialog: Genel Stok Ekle (ürün arayarak) ----
  Future<void> _stokEkleDialog(BuildContext pageContext) async {
    final urunServis = _controller.urunServis;
    final urunler = await urunServis.onceGetir();

    final adetCtrl = TextEditingController();
    Urun? secilen;

    await showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        bool isProcessing = false;
        late TextEditingController typeAheadCtrl;

        return StatefulBuilder(
          builder: (localCtx, setLocal) {
            Future<void> _doEkle() async {
              if (!localCtx.mounted) return;
              setLocal(() => isProcessing = true);

              final ek = int.tryParse(adetCtrl.text.trim()) ?? 0;
              if (secilen == null || ek <= 0 || secilen!.docId == null) {
                if (localCtx.mounted) setLocal(() => isProcessing = false);
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        secilen == null
                            ? "Lütfen ürün seçin."
                            : (ek <= 0
                                  ? "Geçerli bir adet girin."
                                  : "Ürünün belge kimliği yok. Listeyi yenileyin."),
                      ),
                    ),
                  );
                }
                return;
              }

              try {
                await urunServis.adetArtir(secilen!.docId!, ek);

                if (localCtx.mounted) nav.pop();
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Stok eklendi: ${secilen!.urunAdi}"
                        "${(secilen!.renk ?? '').isNotEmpty ? " (${secilen!.renk})" : ""} → +$ek adet. "
                        "Sevkiyat için Siparişler sayfasında Onay'ı kullanın.",
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (localCtx.mounted) nav.pop();
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text("İşlem başarısız: $e")),
                  );
                }
              } finally {
                if (localCtx.mounted) setLocal(() => isProcessing = false);
              }
            }

            return AlertDialog(
              title: const Text("Stok Ekle"),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeAheadField<Urun>(
                      debounceDuration: const Duration(milliseconds: 180),
                      suggestionsCallback: (pattern) {
                        final p = pattern.trim().toLowerCase();
                        if (p.isEmpty) return urunler.take(30).toList();

                        final res = urunler
                            .where((u) {
                              final n = u.urunAdi.toLowerCase();
                              final r = (u.renk ?? '').toLowerCase();
                              return n.contains(p) || r.contains(p);
                            })
                            .take(30)
                            .toList();
                        return res;
                      },
                      itemBuilder: (_, u) => ListTile(
                        dense: true,
                        title: Text(
                          u.urunAdi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "Renk: ${u.renk ?? '-'} | Stok: ${u.adet}",
                        ),
                      ),
                      onSelected: (u) {
                        if (isProcessing) return;
                        secilen = u;
                        typeAheadCtrl.text =
                            "${u.urunAdi}${(u.renk ?? '').isNotEmpty ? " (${u.renk})" : ""}";
                        FocusScope.of(dialogCtx).unfocus();
                      },
                      builder: (ctx, controller, focusNode) {
                        typeAheadCtrl = controller;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: !isProcessing,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Renkler.kahveTon,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            labelText: "Ürün Ara",
                            labelStyle: TextStyle(color: Renkler.kahveTon),
                          ),
                          onSubmitted: (v) {
                            if (isProcessing) return;
                            if (secilen == null) {
                              final p = v.trim().toLowerCase();
                              final first = urunler.firstWhereOrNull(
                                (u) => u.urunAdi.toLowerCase().contains(p),
                              );
                              if (first != null) {
                                secilen = first;
                                controller.text =
                                    "${first.urunAdi}${(first.renk ?? '').isNotEmpty ? " (${first.renk})" : ""}";
                                FocusScope.of(dialogCtx).unfocus();
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adetCtrl,
                      enabled: !isProcessing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Eklenecek Adet",
                        labelStyle: TextStyle(color: Renkler.kahveTon),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Renkler.kahveTon,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => nav.pop(),
                  child: const Text(
                    "İptal",
                    style: TextStyle(color: Renkler.kahveTon),
                  ),
                ),
                ElevatedButton(
                  onPressed: isProcessing ? null : _doEkle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Renkler.kahveTon,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Ekle",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
