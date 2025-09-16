import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/services/urun_service.dart';

class SiparisUrunSecSayfasi extends StatefulWidget {
  final void Function(List<SiparisUrunModel>) onNext;
  final VoidCallback onBack;

  const SiparisUrunSecSayfasi({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SiparisUrunSecSayfasi> createState() => _SiparisUrunSecSayfasiState();
}

class _SiparisUrunSecSayfasiState extends State<SiparisUrunSecSayfasi> {
  final List<SiparisUrunModel> _secilenler = [];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _aramaCtrl = TextEditingController();

  final _srv = UrunService();

  String _arama = "";

  static const int _pageSize = 60;
  int _limit = _pageSize;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _debounce?.cancel();
    _aramaCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() => _limit += _pageSize);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _arama = v;
        _limit = _pageSize;
      });
    });
  }

  int _toplamAdet() => _secilenler.fold(0, (s, e) => s + e.adet);

  SiparisUrunModel? _bulSecim(String urunId) {
    final i = _secilenler.indexWhere((e) => e.id == urunId);
    return (i == -1) ? null : _secilenler[i];
    }

  void _ekleVeyaGuncelle(Urun u, int adet) {
    if (adet <= 0) return;
    final String urunId = u.id.toString();
    setState(() {
      _secilenler.removeWhere((e) => e.id == urunId);
      _secilenler.add(
        SiparisUrunModel(
          id: urunId,
          urunAdi: u.urunAdi,
          renk: u.renk,
          adet: adet,
          birimFiyat: 0,
        ),
      );
    });
  }

  void _arttir(Urun u) {
    final String urunId = u.id.toString();
    final varOlan = _bulSecim(urunId);
    final yeni = (varOlan?.adet ?? 0) + 1;
    _ekleVeyaGuncelle(u, yeni);
  }

  void _azalt(Urun u) {
    final String urunId = u.id.toString();
    final varOlan = _bulSecim(urunId);
    if (varOlan == null) return;
    final yeni = varOlan.adet - 1;
    setState(() {
      _secilenler.removeWhere((e) => e.id == urunId);
      if (yeni > 0) {
        _secilenler.add(
          SiparisUrunModel(
            id: urunId,
            urunAdi: u.urunAdi,
            renk: u.renk,
            adet: yeni,
            birimFiyat: varOlan.birimFiyat,
          ),
        );
      }
    });
  }

  void _kaldir(Urun u) {
    setState(() => _secilenler.removeWhere((e) => e.id == u.id.toString()));
  }

  Future<void> _adetSecBottomSheet(Urun u) async {
    int adet = _bulSecim(u.id.toString())?.adet ?? 1;
    final int stok = u.adet;

    final TextEditingController adetCtrl =
        TextEditingController(text: adet.toString());

    final sonuc = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void syncText() {
            if (adetCtrl.text != adet.toString()) {
              adetCtrl.text = adet.toString();
              adetCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: adetCtrl.text.length),
              );
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${u.urunAdi} | ${u.renk}",
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text("Stok: $stok"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (adet > 1) {
                          setModalState(() => adet--);
                          syncText();
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: adetCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          if (parsed == null || parsed <= 0) {
                            setModalState(() => adet = 1);
                          } else {
                            setModalState(() => adet = parsed);
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setModalState(() => adet++);
                        syncText();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final onayAdet = int.tryParse(adetCtrl.text) ?? adet;
                      Navigator.pop(ctx, onayAdet > 0 ? onayAdet : 1);
                    },
                    child: const Text("Onayla",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    if (sonuc != null && sonuc > 0) {
      _ekleVeyaGuncelle(u, sonuc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Ürün Seçimi",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_secilenler.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Renkler.kahveTon.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Seçili: ${_secilenler.length} ürün • ${_toplamAdet()} adet",
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Arama
          TextField(
            controller: _aramaCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Ürün ara (ad / renk)...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Renkler.kahveTon , width: 2),borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 12),

          if (_secilenler.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _secilenler.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = _secilenler[i];
                  return Chip(
                    label: Text("${e.urunAdi} | ${e.renk} (${e.adet})"),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {
                      setState(() => _secilenler.removeAt(i));
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<List<Urun>>(
              stream: _srv.dinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                var urunler = (snap.data ?? <Urun>[]);

                if (_arama.isNotEmpty) {
                  final q = _arama.toLowerCase();
                  urunler = urunler.where((u) =>
                    u.urunAdi.toLowerCase().contains(q) ||
                    u.renk.toLowerCase().contains(q)
                  ).toList();
                }

                final sliced = urunler.take(_limit).toList();

                if (sliced.isEmpty) {
                  return const Center(child: Text("Ürün bulunamadı."));
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: sliced.length,
                  itemBuilder: (_, i) => _UrunSatir(
                    urun: sliced[i],
                    secim: _bulSecim(sliced[i].id.toString()),
                    kahve: Renkler.kahveTon,
                    arttir: _arttir,
                    azalt: _azalt,
                    kaldir: _kaldir,
                    adetSec: _adetSecBottomSheet,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text("Geri",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => widget.onNext(_secilenler),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text(
                      _toplamAdet() == 0 ? "İleri" : "İleri (${_toplamAdet()})",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrunSatir extends StatelessWidget {
  final Urun urun;
  final SiparisUrunModel? secim;
  final Color kahve;
  final void Function(Urun) arttir;
  final void Function(Urun) azalt;
  final void Function(Urun) kaldir;
  final Future<void> Function(Urun) adetSec;

  const _UrunSatir({
    required this.urun,
    required this.secim,
    required this.kahve,
    required this.arttir,
    required this.azalt,
    required this.kaldir,
    required this.adetSec,
  });

  @override
  Widget build(BuildContext context) {
    final stok = urun.adet;
    final secili = secim != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text("${urun.urunAdi} | ${urun.renk}"),
        subtitle: Text("Stok: $stok"),
        trailing: secili
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Azalt",
                    onPressed: () => azalt(urun),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  GestureDetector(
                    onTap: () => adetSec(urun),
                    child: Text("${secim!.adet}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  IconButton(
                    tooltip: "Arttır",
                    onPressed: () => arttir(urun),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: "Kaldır",
                    onPressed: () => kaldir(urun),
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            : TextButton.icon(
                onPressed: () => adetSec(urun),
                icon: Icon(Icons.add_circle_outline, color: kahve),
                label: Text("Ekle", style: TextStyle(color: kahve)),
              ),
      ),
    );
  }
}
