// lib/pages/moduller/urun_sayfasi/urun_ekle_sayfasi.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/core/models/renk_item.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/renk_service.dart';

class UrunEkleSayfasi extends StatefulWidget {
  final Urun? duzenlenecekUrun;
  final int? urunIndex; // eski yerlerden gelebilir; artık kullanılmıyor

  const UrunEkleSayfasi({super.key, this.duzenlenecekUrun, this.urunIndex});

  @override
  State<UrunEkleSayfasi> createState() => _UrunEkleSayfasiState();
}

class _UrunEkleSayfasiState extends State<UrunEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();

  final UrunService urunService = UrunService();
  final RenkService renkService = RenkService.instance;

  final TextEditingController urunKoduController = TextEditingController();
  final TextEditingController urunAdiController = TextEditingController();
  final TextEditingController adetController = TextEditingController();
  final TextEditingController aciklamaController = TextEditingController();

  String? _secilenRenkAd;

  List<File> secilenResimler = [];
  String? kapakResimYolu;

  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    if (widget.duzenlenecekUrun != null) {
      final urun = widget.duzenlenecekUrun!;
      urunKoduController.text = urun.urunKodu;
      urunAdiController.text = urun.urunAdi;
      _secilenRenkAd = urun.renk.isNotEmpty ? urun.renk : null;
      adetController.text = urun.adet.toString();
      aciklamaController.text = urun.aciklama ?? '';
      if (urun.resimYollari != null && urun.resimYollari!.isNotEmpty) {
        secilenResimler = urun.resimYollari!.map((p) => File(p)).toList();
        kapakResimYolu =
            urun.kapakResimYolu ?? (urun.resimYollari!.isNotEmpty ? urun.resimYollari!.first : null);
      }
    }
  }

  @override
  void dispose() {
    urunKoduController.dispose();
    urunAdiController.dispose();
    adetController.dispose();
    aciklamaController.dispose();
    super.dispose();
  }

  Future<void> resimSec() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        secilenResimler.addAll(picked.map((e) => File(e.path)));
        kapakResimYolu ??= secilenResimler.first.path;
      });
    }
  }

  Future<void> _resimSilDialog(int index) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resmi Sil"),
        content: const Text("Bu resmi silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet, sil")),
        ],
      ),
    );
    if (onay == true) {
      setState(() {
        if (secilenResimler[index].path == kapakResimYolu) kapakResimYolu = null;
        secilenResimler.removeAt(index);
      });
    }
  }

  Future<void> _yeniRenkEkleDialog() async {
    final adCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yeni Renk Ekle"),
        content: TextField(
          controller: adCtrl,
          decoration: const InputDecoration(
            labelText: "Renk adı (zorunlu)",
            hintText: "Örn: Beyaz",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      final ad = adCtrl.text.trim();
      if (ad.isEmpty) return;
      try {
        // 🔁 Positional parametre kullan (sende named değil)
        await renkService.ekle(ad);
        if (!mounted) return;
        setState(() => _secilenRenkAd = ad);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Renk eklendi: $ad")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Renk eklenemedi: $e")),
        );
      }
    }
  }

  Future<void> kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final yeniUrun = Urun(
      id: widget.duzenlenecekUrun?.id ?? 0,
      urunKodu: urunKoduController.text.trim(),
      urunAdi: urunAdiController.text.trim(),
      renk: (_secilenRenkAd ?? '').trim(),
      adet: int.tryParse(adetController.text) ?? 0,
      aciklama: aciklamaController.text.trim(),
      resimYollari: secilenResimler.map((f) => f.path).toList(),
      kapakResimYolu: kapakResimYolu,
    );

    setState(() => _kaydediyor = true);
    try {
      final docId = widget.duzenlenecekUrun?.docId;
      if (docId != null && docId.isNotEmpty) {
        await urunService.guncelle(docId, yeniUrun);
      } else {
        await urunService.ekle(yeniUrun);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Kaydetme başarısız: $e")));
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.duzenlenecekUrun != null;

    return Scaffold(
      appBar: AppBar(title: Text(duzenleme ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'), backgroundColor: Renkler.kahveTon),
      body: AbsorbPointer(
        absorbing: _kaydediyor,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: resimSec,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text("Resim(leri) seçmek için tıklayın")),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(secilenResimler.length, (index) {
                        final file = secilenResimler[index];
                        return GestureDetector(
                          onTap: () => _resimSilDialog(index),
                          onLongPress: () => setState(() => kapakResimYolu = file.path),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
                              ),
                              const Positioned(
                                right: 4, top: 4,
                                child: CircleAvatar(
                                  radius: 12, backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                              if (file.path == kapakResimYolu)
                                const Positioned(
                                  bottom: 4, left: 4,
                                  child: Icon(Icons.star, color: Colors.amber),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: urunKoduController,
                      decoration: const InputDecoration(labelText: "Ürün Kodu", border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: urunAdiController,
                      decoration: const InputDecoration(labelText: "Ürün Adı", border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                    ),
                    const SizedBox(height: 12),

                    _RenkDropdown(
                      seciliAd: _secilenRenkAd,
                      onDegisti: (ad) => setState(() => _secilenRenkAd = ad),
                      onYeniRenk: _yeniRenkEkleDialog,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: adetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Adet", border: OutlineInputBorder()),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return "Geçersiz sayı";
                        if (n < 0) return "Negatif olamaz";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: aciklamaController,
                      decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder()),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
                        onPressed: kaydet,
                        child: Text(duzenleme ? "Kaydet" : "Ekle", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            if (_kaydediyor)
              Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _RenkDropdown extends StatelessWidget {
  final String? seciliAd;
  final ValueChanged<String?> onDegisti;
  final VoidCallback onYeniRenk;

  const _RenkDropdown({
    required this.seciliAd,
    required this.onDegisti,
    required this.onYeniRenk,
  });

  @override
  Widget build(BuildContext context) {
    final svc = RenkService.instance;

    return StreamBuilder<List<RenkItem>>(
      // 🔁 RenkService tarafında 'dinle()' sağlıyoruz
      stream: svc.dinle(),
      builder: (context, snap) {
        final renkler = snap.data ?? [];

        // Düzenle modunda eski renk listede yoksa, geçici seçenek ekle
        final secili = seciliAd?.trim() ?? '';
        final items = [...renkler];
        final varMi = secili.isEmpty
            ? true
            : items.any((r) => r.ad.toLowerCase() == secili.toLowerCase());
        if (!varMi && secili.isNotEmpty) {
          items.insert(0, RenkItem(id: '_local_', ad: secili));
        }

        return DropdownButtonFormField<String>(
          value: secili.isNotEmpty ? secili : null,
          decoration: InputDecoration(
            labelText: "Renk",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: IconButton(onPressed: onYeniRenk, icon: const Icon(Icons.add), tooltip: "Yeni renk ekle"),
          ),
          items: items
              .map((r) => DropdownMenuItem<String>(value: r.ad, child: Text(r.ad)))
              .toList(),
          onChanged: onDegisti,
          validator: (v) => (v == null || v.trim().isEmpty) ? "Renk seçiniz" : null,
          hint: const Text("Renk seçin"),
        );
      },
    );
  }
}
