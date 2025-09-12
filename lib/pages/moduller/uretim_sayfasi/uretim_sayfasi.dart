// lib/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

String fmtDate(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

/// Görünüm için hafif DTO
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

class UretimViewState {
  final bool loading;
  final String? error;
  final List<EksikIstek> eksikListe;
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
            // FIFO sıralamayı burada bir kere yap
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

    // Ürün id -> adet
    final stokMap = <int, int>{for (final u in _cacheUruns) u.id: u.adet};
    final temp = Map<int, int>.from(stokMap);

    final List<EksikIstek> eksikler = [];
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
              "Sipariş: ${fmtDate(sip.tarih)} • Toplam: ${su.adet} • Eksik: $eksik"
              "${acik.isNotEmpty ? " • ${acik}" : ""}";

          eksikler.add(
            EksikIstek(
              siparisDocId: sip.docId ?? '',
              siparisTarihi: sip.tarih,
              musteriAdi: musteriAdi,
              urunId: id,
              urunAdi: su.urunAdi,
              renk: renk,
              toplamIstenen: su.adet,
              eksikAdet: eksik,
              aciklama: aciklama,
            ),
          );
        }
      }
    }

    // Burada istersen önceliklendirme (en eski sipariş, en büyük eksik gibi)
    // eksikler.sort((a,b)=> a.siparisTarihi.compareTo(b.siparisTarihi));

    _out.add(
      UretimViewState.data(eksikListe: eksikler, tumUrunler: _cacheUruns),
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Üretim"),
        backgroundColor: Renkler.kahveTon,
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

          final eksikListe = st.eksikListe;
          final tumUrunler = st.tumUrunler;

          if (eksikListe.isEmpty) {
            return const Center(child: Text("Şu anda bekleyen istek yok."));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "İstek Listesi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    key: const PageStorageKey('uretim-istek-list'),
                    padding: const EdgeInsets.only(bottom: 96),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                    cacheExtent: 600,
                    itemCount: eksikListe.length,
                    itemBuilder: (context, i) {
                      final it = eksikListe[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            "${it.urunAdi} | ${it.renk.isEmpty ? '-' : it.renk}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Firma: ${it.musteriAdi}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                it.aciklama,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          trailing: FilledButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Ekle"),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Renkler.kahveTon,
                              ),
                            ),
                            onPressed: () =>
                                _istekTamamla(context, it, tumUrunler),
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

  // ---- Helpers ----
  static String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  // ---- Dialog: Stok Ekle ----
  Future<void> _stokEkleDialog(BuildContext pageContext) async {
    final urunServis = _controller.urunServis;
    final siparisServis = _controller.siparisServis;
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
                final kac = await siparisServis.allocateFIFOAcrossProduction();

                if (localCtx.mounted) {
                  // kısa başarı ekranı yerine direkt kapatıyoruz
                  nav.pop();
                }
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Stok eklendi: ${secilen!.urunAdi}"
                        "${(secilen!.renk ?? '').isNotEmpty ? " (${secilen!.renk})" : ""} → +$ek adet. "
                        "${kac > 0 ? "$kac sipariş sevkiyata geçti." : ""}",
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
                      // ÖNEMLİ: debounce + limit
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

  // ---- Dialog: İstek Tamamla ----
  // Sipariş ve ürün servisleri kalsın
  final siparisServis = SiparisService();
  final urunServis = UrunService();

  Future<void> _istekTamamla(
    BuildContext parentCtx,
    EksikIstek istek,
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
            title: Text("${istek.urunAdi} Üretimi (${istek.musteriAdi})"),
            content: TextField(
              controller: adetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Üretilen Adet (Eksik: ${istek.eksikAdet})",
                // ... Diğer dekorasyonlar aynı kalır
              ),
              enabled: !isBusy,
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => nav.pop(),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        final uretilen =
                            int.tryParse(adetCtrl.text.trim()) ?? 0;
                        if (uretilen <= 0) {
                          // ... Hata mesajı göster
                          return;
                        }

                        // UI'ı meşgul et
                        setLocal(() => isBusy = true);
                        try {
                          // İŞTE YENİ BÖLÜM BURASI
                          // 1. Ürün stoğunu artır
                          final urun = tumUrunler.firstWhereOrNull(
                            (u) => u.id == istek.urunId,
                          );
                          if (urun == null || urun.docId == null) {
                            // ... Ürün bulunamadı hatası
                            return;
                          }
                          await urunServis.adetArtir(urun.docId!, uretilen);

                          // 2. Siparişin ilgili ürünündeki üretilen miktarını artır
                          // Bu fonksiyonu SiparisService'e eklemen gerekecek
                          final bool siparisTamamlandiMi = await siparisServis
                              .uretilenMiktariGuncelle(
                                istek.siparisDocId,
                                istek.urunId.toString(),
                                uretilen,
                              );

                          // 3. Başarılı mesajı göster
                          if (siparisTamamlandiMi) {
                            // Siparişin tüm ürünleri üretilmişse, sevkiyata geçebilir.
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              const SnackBar(
                                content: Text("Sipariş sevkiyata geçti."),
                              ),
                            );
                          } else {
                            // Siparişin hala eksiği varsa, üretimde kalmaya devam eder.
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              const SnackBar(
                                content: Text("Ürün siparişe eklendi."),
                              ),
                            );
                          }
                          nav.pop(); // Diyaloğu kapat
                        } catch (e) {
                          // ... Hata yönetimi
                        } finally {
                          if (localCtx.mounted) setLocal(() => isBusy = false);
                        }
                      },
                child: isBusy
                    ? const CircularProgressIndicator()
                    : const Text("Tamamla"),
              ),
            ],
          ),
        );
      },
    );
  }
}
