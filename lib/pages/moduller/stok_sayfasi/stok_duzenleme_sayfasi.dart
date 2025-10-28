import 'package:flutter/material.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/core/Color/Colors.dart';

class StokDuzenlemeSayfasi extends StatefulWidget {
  const StokDuzenlemeSayfasi({super.key});

  @override
  State<StokDuzenlemeSayfasi> createState() => _StokDuzenlemeSayfasiState();
}

class _StokDuzenlemeSayfasiState extends State<StokDuzenlemeSayfasi> {
  final UrunService _urunService = UrunService();
  late Future<List<Urun>> _urunlerFuture;

  // Değişiklikleri takip etmek için
  final Map<String, int> _degisiklikler = {};
  // Her ürünün TextField'ını yönetmek için
  final Map<String, TextEditingController> _controllers = {};

  // 💡 YENİ: Arama için state değişkenleri
  final TextEditingController _aramaCtrl = TextEditingController();
  String _aramaQuery = '';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urunlerFuture = _urunService.onceGetir();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _aramaCtrl.dispose(); // 💡 Arama controller'ını temizle
    super.dispose();
  }

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();

    if (_degisiklikler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiçbir değişiklik yapılmadı.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _urunService.topluStokGuncelle(_degisiklikler);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_degisiklikler.length} ürünün stoğu güncellendi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hızlı Stok Düzenleme'),
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
          if (_degisiklikler.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isLoading ? null : _kaydet,
                tooltip: 'Değişiklikleri Kaydet',
              ),
            ),
        ],
      ),
      body: Column(
        // 💡 YAPI GÜNCELLENDİ: Arama çubuğu ve liste için Column
        children: [
          // 💡 YENİ: ARAMA ÇUBUĞU
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _aramaCtrl,
              onChanged: (value) {
                setState(() {
                  _aramaQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Ürün adı, kodu veya renk ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _aramaQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _aramaCtrl.clear();
                            _aramaQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          // 💡 YAPI GÜNCELLENDİ: FutureBuilder Expanded ile sarıldı
          Expanded(
            child: FutureBuilder<List<Urun>>(
              future: _urunlerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Düzenlenecek ürün bulunamadı.'),
                  );
                }

                final tumUrunler = snapshot.data!;

                // 💡 YENİ: FİLTRELEME MANTIĞI
                final List<Urun> gosterilecekUrunler;
                if (_aramaQuery.isEmpty) {
                  gosterilecekUrunler = tumUrunler;
                } else {
                  final query = _aramaQuery.toLowerCase();
                  gosterilecekUrunler = tumUrunler.where((urun) {
                    final ad = urun.urunAdi.toLowerCase();
                    final kod = urun.urunKodu.toLowerCase();
                    final renk = urun.renk.toLowerCase();
                    return ad.contains(query) ||
                        kod.contains(query) ||
                        renk.contains(query);
                  }).toList();
                }

                if (gosterilecekUrunler.isEmpty) {
                  return const Center(
                    child: Text('Arama kriterlerine uygun ürün bulunamadı.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: gosterilecekUrunler
                      .length, // 💡 Filtrelenmiş liste kullanılıyor
                  itemBuilder: (context, index) {
                    final urun =
                        gosterilecekUrunler[index]; // 💡 Filtrelenmiş liste kullanılıyor
                    final docId = urun.docId!;

                    _controllers.putIfAbsent(
                      docId,
                      () => TextEditingController(text: urun.adet.toString()),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text("${urun.urunAdi} | ${urun.renk}"),
                        subtitle: Text("Kod: ${urun.urunKodu}"),
                        trailing: SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _controllers[docId],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final yeniAdet = int.tryParse(value);
                              if (yeniAdet != null && yeniAdet != urun.adet) {
                                _degisiklikler[docId] = yeniAdet;
                              } else {
                                _degisiklikler.remove(docId);
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _degisiklikler.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _kaydet,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isLoading
                    ? 'Kaydediliyor...'
                    : 'Değişiklikleri Kaydet (${_degisiklikler.length})',
              ),
              backgroundColor: Renkler.kahveTon,
            )
          : null,
    );
  }
}
