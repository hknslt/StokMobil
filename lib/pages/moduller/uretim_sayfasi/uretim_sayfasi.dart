// lib/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

/// Ürün + renk + SİPARİŞ bazlı tek bir ihtiyaç kartı
class _EksikIstek {
  final String siparisDocId;
  final DateTime siparisTarihi;
  final String musteriAdi;

  final int urunId;
  final String urunAdi;
  final String renk; // normalize: '' olabilir
  final int toplamIstenen; // o siparişte bu ürün için toplam
  final int eksikAdet; // o siparişte bu ürün için eksik

  final String aciklama; // kartta gösterilecek açıklama

  const _EksikIstek({
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

  _EksikIstek copyWith({int? eksikAdet}) => _EksikIstek(
    siparisDocId: siparisDocId,
    siparisTarihi: siparisTarihi,
    musteriAdi: musteriAdi,
    urunId: urunId,
    urunAdi: urunAdi,
    renk: renk,
    toplamIstenen: toplamIstenen,
    eksikAdet: eksikAdet ?? this.eksikAdet,
    aciklama: aciklama,
  );
}

class UretimSayfasi extends StatefulWidget {
  const UretimSayfasi({super.key});

  @override
  State<UretimSayfasi> createState() => _UretimSayfasiState();
}

class _UretimSayfasiState extends State<UretimSayfasi> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Üretim"),
        backgroundColor: Renkler.kahveTon,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<SiparisModel>>(
          stream: siparisServis.dinle(sadeceDurum: SiparisDurumu.uretimde),
          builder: (context, sipSnap) {
            if (sipSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (sipSnap.hasError) {
              return Center(child: Text('Hata: ${sipSnap.error}'));
            }
            final uretimde = (sipSnap.data ?? []).toList()
              ..sort((a, b) => a.tarih.compareTo(b.tarih)); // FIFO

            return StreamBuilder<List<Urun>>(
              stream: urunServis.dinle(),
              builder: (context, urunSnap) {
                if (urunSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (urunSnap.hasError) {
                  return Center(child: Text('Hata: ${urunSnap.error}'));
                }
                final tumUrunler = urunSnap.data ?? [];

                // Mevcut stok: ürünId -> adet
                final stokMap = <int, int>{
                  for (final u in tumUrunler) u.id: u.adet,
                };

                // ---- EKSİK LİSTESİ (SİPARİŞ BAZLI) ----
                final tempStok = Map<int, int>.from(stokMap);
                final List<_EksikIstek> eksikListe = [];

                for (final sip in uretimde) {
                  final musteriAdi =
                      (sip.musteri.firmaAdi?.trim().isNotEmpty == true)
                      ? sip.musteri.firmaAdi!.trim()
                      : (sip.musteri.yetkili ?? 'Müşteri');

                  for (final su in sip.urunler) {
                    final id = int.tryParse(su.id);
                    if (id == null) continue;

                    final varolan = tempStok[id] ?? 0;
                    if (varolan >= su.adet) {
                      tempStok[id] = varolan - su.adet;
                    } else {
                      final eksik = su.adet - varolan;
                      tempStok[id] = 0;

                      final renkSafe = (su.renk ?? '').trim();
                      final acik = (sip.aciklama ?? '').trim();
                      final aciklama =
                          "Sipariş Tarihi: ${_fmtDate(sip.tarih)} • Toplam: ${su.adet} • Eksik: $eksik"
                          "${acik.isNotEmpty ? " • Açıklama: $acik" : ""}";

                      eksikListe.add(
                        _EksikIstek(
                          siparisDocId: sip.docId ?? '',
                          siparisTarihi: sip.tarih,
                          musteriAdi: musteriAdi,
                          urunId: id,
                          urunAdi: su.urunAdi,
                          renk: renkSafe,
                          toplamIstenen: su.adet,
                          eksikAdet: eksik,
                          aciklama: aciklama,
                        ),
                      );
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "İstek Listesi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (eksikListe.isEmpty)
                      const Text("Şu anda bekleyen istek yok.")
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: eksikListe.length,
                          itemBuilder: (context, index) {
                            final istek = eksikListe[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  "${istek.urunAdi} | ${istek.renk.isEmpty ? '-' : istek.renk}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Firma: ${istek.musteriAdi}"),
                                    const SizedBox(height: 4),
                                    Text(
                                      istek.aciklama,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
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
                                      _istekTamamla(istek, tumUrunler),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
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

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  // ---- Dialog: Stok Ekle (firma/sipariş belirtilmeden -> FIFO dağıt) ----
  Future<void> _stokEkleDialog(BuildContext pageContext) async {
    final urunler = await urunServis.onceGetir();

    final TextEditingController adetController = TextEditingController();
    Urun? secilen;

    // phase: 0=form, 1=processing, 2=done, 3=error
    await showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        int phase = 0;
        final nav = Navigator.of(dialogCtx);
        bool isProcessing = false; // Yeni durum değişkeni

        late TextEditingController typeAheadCtrl;

        return StatefulBuilder(
          builder: (localCtx, setLocal) {
            void setPhase(int p) {
              // setState() çağırmadan önce mounted kontrolü
              if (localCtx.mounted) setLocal(() => phase = p);
            }

            Widget _content() {
              if (phase == 1) {
                // Loading
                return SizedBox(
                  width: 420,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(height: 8),
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text("Stok ekleniyor…", textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              } else if (phase == 2) {
                // Success
                return SizedBox(
                  width: 420,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 36),
                        SizedBox(height: 8),
                        Text("Stok eklendi ✔", textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              } else if (phase == 3) {
                // Error (kısa süre gösterip form'a dönmek istersen burayı değiştir)
                return SizedBox(
                  width: 420,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.error_outline, color: Colors.red, size: 36),
                        SizedBox(height: 8),
                        Text("İşlem başarısız.", textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }

              // phase == 0 : form
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeAheadField<Urun>(
                      suggestionsCallback: (pattern) {
                        final p = pattern.trim().toLowerCase();
                        if (p.isEmpty) return urunler;
                        return urunler
                            .where(
                              (u) =>
                                  u.urunAdi.toLowerCase().contains(p) ||
                                  (u.renk ?? '').toLowerCase().contains(p),
                            )
                            .toList();
                      },
                      itemBuilder: (_, u) => ListTile(
                        title: Text(u.urunAdi),
                        subtitle: Text("Renk: ${u.renk} | Stok: ${u.adet}"),
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
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Renkler.kahveTon,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            labelText: "Ürün Ara",
                            labelStyle: TextStyle(color: Renkler.kahveTon)
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
                      controller: adetController,
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
              );
            }

            List<Widget> _actions() {
              if (phase == 0) {
                // Form aşaması
                return [
                  TextButton(
                    onPressed: isProcessing ? null : () => nav.pop(),
                    child: const Text(
                      "İptal",
                      style: TextStyle(color: Renkler.kahveTon),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            if (!localCtx.mounted) return;
                            setLocal(
                              () => isProcessing = true,
                            ); // İşlemi başlat
                            setPhase(1); // Yükleme ekranına geç

                            final ek =
                                int.tryParse(adetController.text.trim()) ?? 0;
                            if (secilen == null ||
                                ek <= 0 ||
                                secilen!.docId == null) {
                              setPhase(0);
                              if (localCtx.mounted)
                                setLocal(() => isProcessing = false);
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
                              final kac = await siparisServis
                                  .allocateFIFOAcrossProduction();

                              if (localCtx.mounted)
                                setPhase(2); // Başarılı ekranına geç

                              Future.delayed(const Duration(milliseconds: 900), () {
                                if (nav.mounted) nav.pop();
                                if (pageContext.mounted) {
                                  ScaffoldMessenger.of(
                                    pageContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Stok eklendi: ${secilen!.urunAdi}"
                                        "${(secilen!.renk ?? '').isNotEmpty ? " (${secilen!.renk})" : ""} "
                                        "→ +$ek adet. ${kac > 0 ? "$kac sipariş sevkiyata geçti." : ""}",
                                      ),
                                    ),
                                  );
                                }
                              });
                            } catch (e) {
                              if (localCtx.mounted)
                                setPhase(3); // Hata ekranına geç
                              Future.delayed(
                                const Duration(milliseconds: 1500),
                                () {
                                  if (nav.mounted) nav.pop();
                                  if (pageContext.mounted) {
                                    ScaffoldMessenger.of(
                                      pageContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text("İşlem başarısız: $e"),
                                      ),
                                    );
                                  }
                                },
                              );
                            } finally {
                              if (localCtx.mounted)
                                setLocal(
                                  () => isProcessing = false,
                                ); // İşlemi bitir ve butonu aktifleştir
                            }
                          },
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
                ];
              }
              return const <Widget>[];
            }

            return AlertDialog(
              title: const Text("Stok Ekle"),
              content: _content(),
              actions: _actions(),
            );
          },
        );
      },
    );
  }

  Future<void> _istekTamamla(_EksikIstek istek, List<Urun> tumUrunler) async {
    final TextEditingController uretimAdetController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        bool isBusy = false;

        return StatefulBuilder(
          builder: (localCtx, setLocal) => AlertDialog(
            title: Text("${istek.urunAdi} Üretimi (${istek.musteriAdi})"),
            content: TextField(
              controller: uretimAdetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                ),
                labelText: "Üretilen Adet (Eksik: ${istek.eksikAdet})",
                labelStyle: TextStyle(color: Renkler.kahveTon),
              ),
              enabled: !isBusy,
            ),
            actions: [
              TextButton(
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Renkler.kahveTon),
                ),
                onPressed: isBusy ? null : () => nav.pop(),
              ),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Renkler.kahveTon),
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
                    : const Text(
                        "Tamamla",
                        style: TextStyle(color: Colors.white),
                      ),
                onPressed: () async {
                  if (!localCtx.mounted) {
                    return;
                  }
                  setLocal(() => isBusy = true);

                  final uretilen =
                      int.tryParse(uretimAdetController.text.trim()) ?? 0;
                  if (uretilen <= 0) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Geçerli bir adet girin."),
                        ),
                      );
                    }
                    if (localCtx.mounted) setLocal(() => isBusy = false);
                    return;
                  }

                  // loader
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                  }

                  try {
                    final urun = tumUrunler.firstWhereOrNull(
                      (u) => u.id == istek.urunId,
                    );
                    if (urun == null || urun.docId == null) {
                      final rootNav = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      if (rootNav.mounted) rootNav.pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Ürün bulunamadı. Listeyi yenileyin.",
                            ),
                          ),
                        );
                      }
                      if (localCtx.mounted) setLocal(() => isBusy = false);
                      return;
                    }

                    await urunServis.adetArtir(urun.docId!, uretilen);

                    final ok = await siparisServis.sevkiyataGecir(
                      istek.siparisDocId,
                    );

                    final rootNav = Navigator.of(context, rootNavigator: true);
                    if (rootNav.mounted) rootNav.pop();

                    if (ok) {
                      final kac = await siparisServis
                          .allocateFIFOAcrossProduction();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Sipariş sevkiyata geçti. Ek olarak $kac sipariş daha sevkiyata geçti.",
                            ),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Bu siparişin diğer ürünleri eksik, üretimde kalmaya devam ediyor.",
                            ),
                          ),
                        );
                      }
                    }

                    if (nav.mounted) nav.pop();
                  } catch (e) {
                    final rootNav = Navigator.of(context, rootNavigator: true);
                    if (rootNav.mounted) rootNav.pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("İşlem başarısız: $e")),
                      );
                    }
                  } finally {
                    if (localCtx.mounted) setLocal(() => isBusy = false);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
