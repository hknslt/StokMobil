// lib/pages/moduller/fiyat_listesi/fiyat_listesi_sayfasi.dart
import 'dart:async';
import 'package:capri/core/Color/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capri/core/models/urun_model.dart';
import 'package:capri/core/models/fiyat_listesi_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/fiyat_listesi_service.dart';

class FiyatListesiSayfasi extends StatefulWidget {
  const FiyatListesiSayfasi({super.key});

  @override
  State<FiyatListesiSayfasi> createState() => _FiyatListesiSayfasiState();
}

class _FiyatListesiSayfasiState extends State<FiyatListesiSayfasi> {
  final _urunSvc = UrunService();
  final _fiyatSvc = FiyatListesiService.instance;

  String? _seciliListeId;
  FiyatListesi? _seciliListe;

  // UI filtre/sıralama
  final TextEditingController _aramaCtrl = TextEditingController();
  bool _sadeceSifirFiyatli = false;
  String _sirala = "İsim (A-Z)"; // "Net ↑", "Net ↓"

  // (Artık parent rebuild tetiklemeyecek) — sadece bilgi amaçlı
  int? _editingId;

  // Alt özetleri titreştirmemek için debounce
  Timer? _sumDebounce;

  // Alt özet için hafif tetikleyici
  final ValueNotifier<int> _ozetTick = ValueNotifier<int>(0);

  // Controller & Focus cache (ürün id -> controller/focus)
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  void _resetControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  TextEditingController _controllerFor(int urunId, double baslangicNet) {
    return _controllers.putIfAbsent(
      urunId,
      () => TextEditingController(
        text: baslangicNet == 0 ? "" : baslangicNet.toStringAsFixed(2),
      ),
    );
  }

  FocusNode _focusFor(int urunId) {
    return _focusNodes.putIfAbsent(urunId, () => FocusNode());
  }

  // ---------- Stream cache ----------
  late final Stream<List<FiyatListesi>> _listelerStream;
  Stream<Map<int, double>>? _fiyatStream;

  @override
  void initState() {
    super.initState();
    _listelerStream = _fiyatSvc.listeleriDinle();
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    _sumDebounce?.cancel();
    _ozetTick.dispose();
    _resetControllers();
    super.dispose();
  }

  // Toplu kaydet
  Future<void> _kaydet() async {
    if (_seciliListeId == null) return;
    final Map<int, double> guncel = {};
    for (final entry in _controllers.entries) {
      final val = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0;
      guncel[entry.key] = val;
    }
    await _fiyatSvc.urunFiyatlariniKaydet(_seciliListeId!, guncel);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Fiyatlar kaydedildi.")));
  }

  // KDV bottom sheet
  void _kdvBottomSheet(FiyatListesi liste) {
    double tmpVal = (liste.kdv).clamp(0, 100);
    final tmpCtrl = TextEditingController(text: tmpVal.toStringAsFixed(2));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(c).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "KDV Oranı",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Slider(
                  activeColor: Renkler.kahveTon,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  value: tmpVal,
                  label: "${tmpVal.toStringAsFixed(0)}%",
                  onChanged: (v) {
                    setModalState(() {
                      tmpVal = v;
                      tmpCtrl.text = v.toStringAsFixed(2);
                    });
                  },
                ),
                TextField(
                  controller: tmpCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,3}(\.\d{0,2})?$'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: "KDV (%)",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    suffixText: "%",
                    suffixStyle: TextStyle(color: Renkler.kahveTon),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v.replaceAll(',', '.'));
                    if (d != null) {
                      setModalState(() => tmpVal = d.clamp(0, 100));
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        Renkler.kahveTon,
                      ),
                    ),
                    onPressed: () async {
                      await _fiyatSvc.kdvGuncelle(
                        listeId: _seciliListe!.id,
                        kdv: tmpVal,
                      );
                      if (!mounted) return;
                      final cur = _seciliListe!;
                      setState(() {
                        _seciliListe = FiyatListesi(
                          id: cur.id,
                          ad: cur.ad,
                          kdv: tmpVal,
                          createdAt: cur.createdAt,
                        );
                      });
                      _ozetTick.value++;
                      if (c.mounted) Navigator.pop(c);
                    },
                    child: const Text("Uygula"),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  // Yeni fiyat listesi oluştur
  void _yeniListeDialog() {
    final adCtrl = TextEditingController();
    final kdvCtrl = TextEditingController(text: "20");
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Yeni Fiyat Listesi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adCtrl,
              decoration: const InputDecoration(
                labelText: "Fiyat listesi adı",
                labelStyle: TextStyle(color: Renkler.kahveTon),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    style: BorderStyle.solid,
                    color: Renkler.kahveTon,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: kdvCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}(\.\d{0,2})?$'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: "KDV (%)",
                labelStyle: TextStyle(color: Renkler.kahveTon),
                suffixText: "%",
                suffixStyle: TextStyle(color: Renkler.kahveTon),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon),borderRadius: BorderRadius.all(Radius.circular(12))
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon),borderRadius: BorderRadius.all(Radius.circular(12))
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon, width: 2),borderRadius: BorderRadius.all(Radius.circular(12))
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "İptal",
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Renkler.kahveTon),
            ),
            onPressed: () async {
              final ad = adCtrl.text.trim();
              final kdv =
                  double.tryParse(kdvCtrl.text.replaceAll(',', '.')) ?? 20;
              if (ad.isEmpty) return;
              final yeniId = await _fiyatSvc.yeniFiyatListesiOlustur(
                ad,
                kdvYuzde: kdv,
              );
              if (!mounted) return;
              Navigator.pop(c);
              setState(() {
                _selectListe(
                  FiyatListesi(
                    id: yeniId,
                    ad: ad,
                    kdv: kdv,
                    createdAt: DateTime.now(),
                  ),
                );
              });
            },
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Fiyat listesi sil (uzun basınca)
  Future<void> _listeyiSil(FiyatListesi l) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Fiyat listesini sil"),
        content: Text(
          "'${l.ad}' listesini ve içindeki tüm ürün fiyatlarını silmek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              "Vazgeç",
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Renkler.kahveTon),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              "Evet, sil",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (onay == true) {
      await _fiyatSvc.listeSil(l.id);
      if (!mounted) return;
      setState(() {
        if (_seciliListeId == l.id) {
          _seciliListeId = null;
          _seciliListe = null;
          _fiyatStream = null;
          _editingId = null;
          _resetControllers();
        }
      });
    }
  }

  // Ürün filtresi/sıralaması (editing sırasında parent rebuild’e gerek yok)
  List<Urun> _filtreleSirala(List<Urun> urunler, Map<int, double> fiyatMap) {
    final q = _aramaCtrl.text.trim().toLowerCase();

    // filtre
    List<Urun> liste = urunler.where((u) {
      final ctrl = _controllers[u.id];
      final net = ctrl == null
          ? (fiyatMap[u.id] ?? 0)
          : (double.tryParse(ctrl.text.replaceAll(',', '.')) ??
                (fiyatMap[u.id] ?? 0));

      final matchArama =
          q.isEmpty ||
          u.urunAdi.toLowerCase().contains(q) ||
          (u.urunKodu?.toLowerCase().contains(q) ?? false) ||
          (u.renk?.toLowerCase().contains(q) ?? false);

      final matchSifir = !_sadeceSifirFiyatli || net == 0;
      return matchArama && matchSifir;
    }).toList();

    // Sıralama (yazarken zaten parent setState etmiyoruz, bu yüzden liste stabil)
    switch (_sirala) {
      case "Net ↑":
        liste.sort(
          (a, b) => (fiyatMap[a.id] ?? 0).compareTo(fiyatMap[b.id] ?? 0),
        );
        break;
      case "Net ↓":
        liste.sort(
          (a, b) => (fiyatMap[b.id] ?? 0).compareTo(fiyatMap[a.id] ?? 0),
        );
        break;
      default:
        liste.sort(
          (a, b) => a.urunAdi.toLowerCase().compareTo(b.urunAdi.toLowerCase()),
        );
    }
    return liste;
  }

  // Seçili listeyi ve stream’ini tek yerden ayarla
  void _selectListe(FiyatListesi l) {
    _seciliListeId = l.id;
    _seciliListe = l;
    _fiyatSvc.setAktifListe(l);
    _fiyatStream = _fiyatSvc.urunFiyatlariniDinle(l.id);
    _editingId = null;
    _resetControllers();
  }

  // Sadece alt özet panelini tazele (listeyi rebuild etmeden)
  void _softRecalcAltOzet() {
    _sumDebounce?.cancel();
    _sumDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _ozetTick.value++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Klavye açılırken Scaffold’u yeniden boyutlandırma
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Renkler.kahveTon,
        title: Text(
          "Fiyat Listeleri${_seciliListe != null ? " • ${_seciliListe!.ad}" : ""}",
        ),
        actions: [
          if (_seciliListe != null)
            IconButton(
              tooltip: "KDV Oranı",
              onPressed: () => _kdvBottomSheet(_seciliListe!),
              icon: const Icon(Icons.percent),
            ),
          IconButton(
            tooltip: "Yeni Liste",
            onPressed: _yeniListeDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<FiyatListesi>>(
        stream: _listelerStream,
        builder: (context, listSnap) {
          if (listSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (listSnap.hasError) {
            return Center(child: Text("Hata: ${listSnap.error}"));
          }
          final listeler = listSnap.data ?? [];
          if (listeler.isEmpty) {
            return const Center(
              child: Text("Henüz fiyat listesi yok. '+' ile ekleyin."),
            );
          }

          if (_seciliListeId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectListe(listeler.first));
            });
          } else {
            final l = listeler.firstWhere(
              (e) => e.id == _seciliListeId,
              orElse: () => listeler.first,
            );
            _seciliListe = l;
          }

          final chipBar = SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final l = listeler[i];
                final selected = _seciliListeId == l.id;
                return GestureDetector(
                  onLongPress: () => _listeyiSil(l),
                  child: ChoiceChip(
                    label: Text(l.ad),
                    selectedColor: Renkler.kahveTon,
                    selected: selected,
                    onSelected: (_) {
                      if (_seciliListeId == l.id) return;
                      setState(() => _selectListe(l));
                    },
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: listeler.length,
            ),
          );

          final fiyatStream = _fiyatStream;
          if (fiyatStream == null) {
            return Column(
              children: const [
                SizedBox(height: 56),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            );
          }

          return Column(
            children: [
              chipBar,

              // Arama + Sıralama
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: // Yeni Hali
                      TextField(
                        controller: _aramaCtrl,
                        decoration: const InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Renkler.kahveTon,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          prefixIcon: Icon(Icons.search),
                          hintText: "Ürün adı / kodu / renk ara",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sirala,
                        items: const [
                          DropdownMenuItem(
                            value: "İsim (A-Z)",
                            child: Text("İsim (A-Z)"),
                          ),
                          DropdownMenuItem(
                            value: "Net ↑",
                            child: Text("Net ↑"),
                          ),
                          DropdownMenuItem(
                            value: "Net ↓",
                            child: Text("Net ↓"),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _sirala = v ?? "İsim (A-Z)"),
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                activeColor: Renkler.kahveTon,
                dense: true,
                title: const Text("Sadece net fiyatı 0 olanları göster"),
                value: _sadeceSifirFiyatli,
                onChanged: (v) => setState(() => _sadeceSifirFiyatli = v),
              ),

              Expanded(
                child: StreamBuilder<List<Urun>>(
                  stream: _urunSvc.dinle(),
                  builder: (context, urunSnap) {
                    if (urunSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (urunSnap.hasError) {
                      return Center(child: Text("Hata: ${urunSnap.error}"));
                    }
                    final urunler = urunSnap.data ?? [];

                    return StreamBuilder<Map<int, double>>(
                      stream: fiyatStream,
                      builder: (context, fiyatSnap) {
                        if (fiyatSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (fiyatSnap.hasError) {
                          return Center(
                            child: Text("Hata: ${fiyatSnap.error}"),
                          );
                        }
                        final fiyatMap = fiyatSnap.data ?? <int, double>{};

                        final filtreli = _filtreleSirala(urunler, fiyatMap);
                        final kdv = _seciliListe?.kdv ?? 20;

                        return Column(
                          children: [
                            // Ürün listesi
                            Expanded(
                              child: ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.manual,
                                addAutomaticKeepAlives: true,
                                addRepaintBoundaries: true,
                                itemCount: filtreli.length,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final urun = filtreli[index];
                                  final mevcutNet = fiyatMap[urun.id] ?? 0;
                                  final ctrl = _controllerFor(
                                    urun.id,
                                    mevcutNet,
                                  );
                                  final focus = _focusFor(urun.id);

                                  return FiyatSatiri(
                                    key: ValueKey('fiyat-row-${urun.id}'),
                                    urun: urun,
                                    mevcutNet: mevcutNet,
                                    kdv: kdv,
                                    controller: ctrl,
                                    focusNode: focus,

                                    // 🔻 ÖNEMLİ: Artık parent’ta setState yok
                                    onStartEdit: () {
                                      _editingId = urun
                                          .id; // sadece state değişkeni; rebuild yok
                                    },
                                    onEndEdit: () {
                                      _editingId = null; // rebuild yok
                                    },

                                    onSoftChange: _softRecalcAltOzet,
                                  );
                                },
                              ),
                            ),

                            // Alt özet + Kaydet (yalnızca tetikleyiciyle güncelleniyor)
                            ValueListenableBuilder<int>(
                              valueListenable: _ozetTick,
                              builder: (_, __, ___) {
                                int girili = 0;
                                double toplamNet = 0;
                                for (final u in urunler) {
                                  final c = _controllers[u.id];
                                  final val = c == null
                                      ? (fiyatMap[u.id] ?? 0)
                                      : (double.tryParse(
                                              c.text.replaceAll(',', '.'),
                                            ) ??
                                            0);
                                  if (val > 0) girili++;
                                  toplamNet += val;
                                }
                                final toplamBrut = toplamNet * (1 + kdv / 100);

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              _istatistikMini(
                                                context,
                                                icon: Icons.inventory_2,
                                                etiket: "Toplam",
                                                deger: urunler.length
                                                    .toString(),
                                              ),
                                              const SizedBox(width: 8),
                                              _istatistikMini(
                                                context,
                                                icon: Icons.check_circle,
                                                etiket: "Girili",
                                                deger: girili.toString(),
                                              ),
                                              const SizedBox(width: 8),
                                              _istatistikMini(
                                                context,
                                                icon: Icons.receipt_long,
                                                etiket: "Brüt",
                                                deger:
                                                    "${toplamBrut.toStringAsFixed(2)} ₺",
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _kaydet,
                                        icon: const Icon(Icons.save, size: 18),
                                        label: const Text("Kaydet"),
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStatePropertyAll(
                                                Renkler.kahveTon,
                                              ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          padding: WidgetStatePropertyAll(
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _istatistikMini(
    BuildContext context, {
    required IconData icon,
    required String etiket,
    required String deger,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deger,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                etiket,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FiyatSatiri extends StatefulWidget {
  final Urun urun;
  final double mevcutNet;
  final double kdv;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onStartEdit;
  final VoidCallback onEndEdit;
  final VoidCallback onSoftChange;

  const FiyatSatiri({
    super.key,
    required this.urun,
    required this.mevcutNet,
    required this.kdv,
    required this.controller,
    required this.focusNode,
    required this.onStartEdit,
    required this.onEndEdit,
    required this.onSoftChange,
  });

  @override
  State<FiyatSatiri> createState() => _FiyatSatiriState();
}

class _FiyatSatiriState extends State<FiyatSatiri>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final urun = widget.urun;
    final ctrl = widget.controller;
    final kdv = widget.kdv;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol - ürün bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urun.urunAdi,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: -4,
                    children: [
                      if (urun.urunKodu != null && urun.urunKodu!.isNotEmpty)
                        Chip(
                          label: Text("Kod: ${urun.urunKodu}"),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (urun.renk != null && urun.renk!.isNotEmpty)
                        Chip(
                          label: Text("Renk: ${urun.renk}"),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: ctrl,
                    builder: (context, value, _) {
                      final cur =
                          double.tryParse(value.text.replaceAll(',', '.')) ??
                          widget.mevcutNet;
                      final brut = (cur * (1 + kdv / 100)).toStringAsFixed(2);
                      return Text(
                        "Brüt: $brut ₺  (KDV %${kdv.toStringAsFixed(2)})",
                        style: const TextStyle(color: Colors.green),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Sağ - Net fiyat girişi
            SizedBox(
              width: 150,
              child: TextField(
                key: ValueKey('tf-${urun.id}'),
                controller: ctrl,
                focusNode: widget.focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,8}(\.\d{0,2})?$'),
                  ),
                ],
                enableIMEPersonalizedLearning: false,
                decoration: const InputDecoration(
                  labelText: "Net Fiyat",
                  labelStyle: TextStyle(color: Renkler.kahveTon),
                  suffixText: "₺",
                  suffixStyle: TextStyle(color: Renkler.kahveTon),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Renkler.kahveTon),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  isDense: true,
                ),
                onTap: () {
                  widget.onStartEdit();
                  FocusScope.of(context).requestFocus(widget.focusNode);
                },
                onChanged: (_) => widget.onSoftChange(),
                onSubmitted: (_) => widget.onEndEdit(),
                onTapOutside: (_) => widget.onEndEdit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
