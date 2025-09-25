
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/core/models/fiyat_listesi_model.dart';
import 'package:capri/services/fiyat_listesi_service.dart';

class SiparisFiyatlandirmaSayfasi extends StatefulWidget {
  final List<SiparisUrunModel> secilenUrunler;
  final void Function(List<SiparisUrunModel>) onNext;
  final VoidCallback onBack;

  const SiparisFiyatlandirmaSayfasi({
    super.key,
    required this.secilenUrunler,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SiparisFiyatlandirmaSayfasi> createState() =>
      _SiparisFiyatlandirmaSayfasiState();
}

class _SiparisFiyatlandirmaSayfasiState
    extends State<SiparisFiyatlandirmaSayfasi> {
  final _svc = FiyatListesiService.instance;
  late List<SiparisUrunModel> urunler;
  String? _seciliListeId;
  String? _seciliListeAd;
  bool _ilkUygulamaYapildi = false;
  final Map<String, TextEditingController> _priceCtrls = {};
  final Map<String, FocusNode> _priceFocus = {};

  late final Stream<List<FiyatListesi>> _listelerStream;
  Stream<Map<int, double>>? _urunFiyatStream;

  @override
  void initState() {
    super.initState();
    urunler = widget.secilenUrunler.map((e) => e.copy()).toList();
    _listelerStream = _svc.listeleriDinle();
  }

  @override
  void dispose() {
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    for (final f in _priceFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String id, double v) =>
      _priceCtrls.putIfAbsent(
        id,
        () => TextEditingController(text: v == 0 ? "" : v.toStringAsFixed(2)),
      );
  FocusNode _focusFor(String id) =>
      _priceFocus.putIfAbsent(id, () => FocusNode());
  String _fmt(double v) => v.toStringAsFixed(2);

  void _setAktifListe(FiyatListesi l) {
    _seciliListeId = l.id;
    _seciliListeAd = l.ad;
    _ilkUygulamaYapildi = false;
    _svc.setAktifListe(l);
    _urunFiyatStream = _svc.urunFiyatlariniDinle(l.id);
  }

  void _uygulaListeFiyati(
    Map<int, double> fiyatMap, {
    required bool overrideAll,
  }) {
    bool changed = false;
    for (final u in urunler) {
      final nid = int.tryParse(u.id);
      final net = nid == null ? 0.0 : (fiyatMap[nid] ?? 0.0);
      if (net > 0 && (overrideAll || u.birimFiyat == 0)) {
        if (u.birimFiyat != net) {
          u.birimFiyat = net;
          changed = true;
        }
        final f = _focusFor(u.id);
        if (!f.hasFocus) {
          final c = _ctrlFor(u.id, net);
          final t = net == 0 ? "" : net.toStringAsFixed(2);
          if (c.text != t) {
            c.text = t;
            c.selection = TextSelection.collapsed(offset: t.length);
          }
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  double _calcBrut(double net, double kdv) => net * (1 + kdv / 100);
  double get _netToplam => urunler.fold(0, (s, u) => s + u.adet * u.birimFiyat);
  double _kdvTutar(double kdv) => _netToplam * (kdv / 100);
  double _brutToplam(double kdv) => _netToplam + _kdvTutar(kdv);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FiyatListesi>>(
      stream: _listelerStream,
      builder: (context, listSnap) {
        if (listSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (listSnap.hasError)
          return Center(child: Text("Hata: ${listSnap.error}"));

        final listeler = listSnap.data ?? [];
        if (listeler.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Henüz fiyat listesi yok. Lütfen bir fiyat listesi oluşturun.",
              ),
            ),
          );
        }
        if (_seciliListeId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _setAktifListe(listeler.first));
          });
        }

        final fiyatStream = _urunFiyatStream;
        if (fiyatStream == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<Map<int, double>>(
          stream: fiyatStream,
          builder: (context, fiyatSnap) {
            final fiyatMap = fiyatSnap.data ?? const <int, double>{};

            final double seciliKdv = (() {
              try {
                final l = listeler.firstWhere((e) => e.id == _seciliListeId);
                return l.kdv;
              } catch (_) {
                return 0.0;
              }
            })();

            if (!_ilkUygulamaYapildi &&
                fiyatMap.isNotEmpty &&
                _seciliListeId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _uygulaListeFiyati(fiyatMap, overrideAll: false);
                _ilkUygulamaYapildi = true;
              });
            }

            return Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _seciliListeId,
                            items: listeler
                                .map(
                                  (l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(l.ad),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final secili = listeler.firstWhere(
                                (e) => e.id == v,
                              );
                              setState(() => _setAktifListe(secili));
                              _uygulaListeFiyati(fiyatMap, overrideAll: false);
                            },
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _uygulaListeFiyati(fiyatMap, overrideAll: true),
                        icon: const Icon(Icons.playlist_add_check , color:Colors.black),
                        label: const Text(
                          "Tümüne uygula",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      if (_seciliListeAd != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            _seciliListeAd!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    itemCount: urunler.length,
                    itemBuilder: (context, i) {
                      final u = urunler[i];
                      final nid = int.tryParse(u.id);
                      final listeNet = nid == null
                          ? 0.0
                          : (fiyatMap[nid] ?? 0.0);
                      final c = _ctrlFor(u.id, u.birimFiyat);
                      final f = _focusFor(u.id);
                      final should = u.birimFiyat == 0
                          ? ""
                          : u.birimFiyat.toStringAsFixed(2);
                      if (!f.hasFocus && c.text != should) {
                        c.text = should;
                        c.selection = TextSelection.collapsed(
                          offset: c.text.length,
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      u.urunAdi,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "Liste: ₺${_fmt(listeNet)}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text("Adet: ${u.adet}"),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: c,
                                      focusNode: f,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: "Birim Fiyat",
                                        prefixText: "₺",
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        final parsed =
                                            double.tryParse(
                                              val.replaceAll(',', '.'),
                                            ) ??
                                            0;
                                        setState(() => u.birimFiyat = parsed);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () {
                                      u.birimFiyat = listeNet;
                                      if (!f.hasFocus) {
                                        c.text = listeNet == 0
                                            ? ""
                                            : listeNet.toStringAsFixed(2);
                                        c.selection = TextSelection.collapsed(
                                          offset: c.text.length,
                                        );
                                      }
                                      setState(() {});
                                    },
                                    child: const Text("Liste fiyatı", style: TextStyle(color: Renkler.kahveTon),),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Birim Fiyat(Brüt): ₺${_fmt(_calcBrut(u.birimFiyat, seciliKdv))}  (KDV %${seciliKdv.toStringAsFixed(2)})",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: const Border(top: BorderSide(color: Colors.grey)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Net Toplam:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            "₺${_fmt(_netToplam)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "KDV (%${seciliKdv.toStringAsFixed(2)}):",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            "₺${_fmt(_kdvTutar(seciliKdv))}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Genel Toplam (Brüt):",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "₺${_fmt(_brutToplam(seciliKdv))}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Renkler.kahveTon,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: widget.onBack,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Geri",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Renkler.kahveTon,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => widget.onNext(urunler),
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "İleri",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        );
      },
    );
  }
}
