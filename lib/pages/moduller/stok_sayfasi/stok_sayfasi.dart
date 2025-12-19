import 'dart:io';
import 'package:capri/pages/moduller/stok_sayfasi/stok_duzenleme_sayfasi.dart';
import 'package:capri/pages/moduller/stok_sayfasi/utils/stok_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/urun_ekle_sayfasi.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/urun_detay_sayfasi.dart';
import 'package:capri/services/urun_yonetimi/renk_service.dart';

class StokSayfasi extends StatefulWidget {
  const StokSayfasi({super.key});

  @override
  State<StokSayfasi> createState() => _StokSayfasiState();
}

class _StokSayfasiState extends State<StokSayfasi> {
  final _srv = UrunService();
  final _aramaCtrl = TextEditingController();
  final Set<int> _seciliUrunIdleri = {};

  bool? _stoktaOlanlar;
  String? _secilenRenk; // '' veya null => Tümü
  String? _siralamaTuru;

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  void _sayfayiYenile() {
    setState(() {});
  }

  Future<void> _exportPdf() async {
    var items = await _srv.onceGetir();

    final aranan = _aramaCtrl.text.toLowerCase();

    items = items.where((u) {
      final stokFiltre = _stoktaOlanlar == null
          ? true
          : _stoktaOlanlar!
          ? u.adet > 0
          : u.adet == 0;

      final renkFiltre = (_secilenRenk == null || _secilenRenk!.isEmpty)
          ? true
          : u.renk.toLowerCase() == _secilenRenk!.toLowerCase();

      final aramaFiltre =
          u.urunAdi.toLowerCase().contains(aranan) ||
          u.urunKodu.toLowerCase().contains(aranan);

      return stokFiltre && renkFiltre && aramaFiltre;
    }).toList();

    if (_siralamaTuru == "A-Z") {
      items.sort((a, b) => a.urunAdi.compareTo(b.urunAdi));
    } else if (_siralamaTuru == "Z-A") {
      items.sort((a, b) => b.urunAdi.compareTo(a.urunAdi));
    } else if (_siralamaTuru == "Stok Artan") {
      items.sort((a, b) => a.adet.compareTo(b.adet));
    } else if (_siralamaTuru == "Stok Azalan") {
      items.sort((a, b) => b.adet.compareTo(a.adet));
    }

    await stokPdfYazdir(items);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(
      context,
    ).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stok Yönetimi"),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Hızlı Stok Düzenle',
            onPressed: () async {
              final sonuc = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const StokDuzenlemeSayfasi(),
                ),
              );
              if (sonuc == true && mounted) {
                _sayfayiYenile();
              }
            },
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final eklendiMi = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UrunEkleSayfasi()),
          );
          if (eklendiMi == true && mounted) setState(() {});
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yeni Ürün", style: TextStyle(color: Colors.white)),
        backgroundColor: Renkler.kahveTon,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // 🔧 Tek kaydırılabilir yapı + klavye kadar alt padding
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 🔍 Arama
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: _aramaCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Ara (ürün adı veya kodu)",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Renkler.kahveTon,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                _filtrePaneli(),
                const SizedBox(height: 8),
              ]),
            ),
          ),

          // 📋 Liste – Firestore Stream (sliver olarak)
          StreamBuilder<List<Urun>>(
            stream: _srv.dinle(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Hata: ${snap.error}')),
                );
              }

              var items = snap.data ?? [];

              // Filtreleme
              final aranan = _aramaCtrl.text.toLowerCase();
              items = items.where((u) {
                final stokFiltre = _stoktaOlanlar == null
                    ? true
                    : _stoktaOlanlar!
                    ? u.adet > 0
                    : u.adet == 0;

                final renkFiltre =
                    (_secilenRenk == null || _secilenRenk!.isEmpty)
                    ? true
                    : u.renk.toLowerCase() == _secilenRenk!.toLowerCase();

                final aramaFiltre =
                    u.urunAdi.toLowerCase().contains(aranan) ||
                    u.urunKodu.toLowerCase().contains(aranan);

                return stokFiltre && renkFiltre && aramaFiltre;
              }).toList();

              // Sıralama
              if (_siralamaTuru == "A-Z") {
                items.sort((a, b) => a.urunAdi.compareTo(b.urunAdi));
              } else if (_siralamaTuru == "Z-A") {
                items.sort((a, b) => b.urunAdi.compareTo(a.urunAdi));
              } else if (_siralamaTuru == "Stok Artan") {
                items.sort((a, b) => a.adet.compareTo(b.adet));
              } else if (_siralamaTuru == "Stok Azalan") {
                items.sort((a, b) => b.adet.compareTo(a.adet));
              }

              if (items.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Ürün bulunamadı.")),
                );
              }

              return SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSecili = _seciliUrunIdleri.contains(item.id);

                  return Slidable(
                    key: Key(item.docId ?? '${item.id}'),
                    startActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: [
                        // ✏️ Düzenle
                        SlidableAction(
                          onPressed: (_) async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UrunEkleSayfasi(duzenlenecekUrun: item),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          icon: Icons.edit,
                          label: "Düzenle",
                          backgroundColor: Colors.blue,
                          borderRadius: BorderRadius.circular(16),
                        ),

                        // 🗑️ Sil (Onaylı)
                        SlidableAction(
                          onPressed: (_) async {
                            final onay =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Silinsin mi?"),
                                    content: Text(
                                      "\"${item.urunAdi}\" ürünü silinecek. Emin misiniz?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text(
                                          "İptal",
                                          style: TextStyle(
                                            color: Renkler.kahveTon,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          "Sil",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (!onay) return;
                            if (!mounted) return;

                            if (item.docId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Kayıt bulunamadı (docId yok).",
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await _srv.sil(item.docId!);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Ürün silindi.")),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Silme başarısız: $e")),
                              );
                            }
                          },
                          icon: Icons.delete,
                          label: "Sil",
                          backgroundColor: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ],
                    ),

                    // 🧾 Satır
                    child: Card(
                      color: isSecili ? Colors.blue.shade100 : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UrunDetaySayfasi(urun: item),
                            ),
                          );
                        },
                        leading: _urunResmi(item),
                        title: Text(item.urunAdi),
                        subtitle: Text(
                          "Kod: ${item.urunKodu} | Renk: ${item.renk}",
                        ),
                        trailing: Text("${item.adet}"),
                        onLongPress: () {
                          setState(() {
                            if (isSecili) {
                              _seciliUrunIdleri.remove(item.id);
                            } else {
                              _seciliUrunIdleri.add(item.id);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---- UI yardımcıları ----

  Widget _urunResmi(Urun item) {
    final path = item.kapakResimYolu;
    if (path == null || path.isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        size: 40,
        color: Colors.grey,
      );
    }
    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(path, width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _filtrePaneli() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Row(
        children: const [
          Icon(Icons.filter_list, color: Renkler.kahveTon),
          SizedBox(width: 8),
          Text(
            "Filtrele & Sırala",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      children: [
        Card(
          elevation: 4,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Stok Durumu",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text("Tümü"),
                      selected: _stoktaOlanlar == null,
                      onSelected: (_) => setState(() => _stoktaOlanlar = null),
                      selectedColor: Renkler.kahveTon,
                    ),
                    FilterChip(
                      label: const Text("Stokta Olan"),
                      selected: _stoktaOlanlar == true,
                      onSelected: (_) => setState(() => _stoktaOlanlar = true),
                      selectedColor: Renkler.kahveTon,
                    ),
                    FilterChip(
                      label: const Text("Stokta Olmayan"),
                      selected: _stoktaOlanlar == false,
                      onSelected: (_) => setState(() => _stoktaOlanlar = false),
                      selectedColor: Renkler.kahveTon,
                    ),
                  ],
                ),

                const Divider(height: 28),

                const Text(
                  "Renge Göre",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),

                // 🔽 Renkler: Firestore’dan
                StreamBuilder<List<String>>(
                  stream: RenkService.instance.dinleAdlar(),
                  builder: (context, snap) {
                    final renkler = snap.data ?? const <String>[];
                    final items = <String>['', ...renkler];

                    if ((_secilenRenk ?? '').isNotEmpty &&
                        !items.contains(_secilenRenk)) {
                      items.add(_secilenRenk!);
                    }

                    return DropdownButtonFormField<String>(
                      value: _secilenRenk ?? '',
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: items
                          .map(
                            (ad) => DropdownMenuItem<String>(
                              value: ad,
                              child: Text(ad.isEmpty ? "Tümü" : ad),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _secilenRenk = (v == null || v.isEmpty) ? null : v;
                      }),
                    );
                  },
                ),

                const Divider(height: 28),

                const Text(
                  "Sıralama",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _siralamaTuru,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [null, "A-Z", "Z-A", "Stok Artan", "Stok Azalan"]
                      .map(
                        (sir) => DropdownMenuItem(
                          value: sir,
                          child: Text(sir ?? "Varsayılan"),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _siralamaTuru = v),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _stoktaOlanlar = null;
                            _secilenRenk = null;
                            _siralamaTuru = null;
                            _aramaCtrl.clear();
                          });
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 18,
                          color: Renkler.kahveTon,
                        ),
                        label: const Text(
                          "Sıfırla",
                          style: TextStyle(color: Renkler.kahveTon),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
