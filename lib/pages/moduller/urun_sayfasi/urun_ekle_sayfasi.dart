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
  final int? urunIndex;

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

  // 🔹 Düzenleme modunda var olan (URL) resimler
  final List<String> _existingUrls = [];

  // 🔹 Bu ekranda yeni seçilen (yerel) resimler
  final List<File> _newLocalFiles = [];

  // 🔹 Kapak seçimi
  String? _coverUrl; // varsa: mevcut URL’den seçildi
  String? _coverLocalPath; // varsa: yerel dosyadan seçildi

  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();

    final u = widget.duzenlenecekUrun;
    if (u != null) {
      urunKoduController.text = u.urunKodu;
      urunAdiController.text = u.urunAdi;
      _secilenRenkAd = u.renk.isNotEmpty ? u.renk : null;
      adetController.text = u.adet.toString();
      aciklamaController.text = u.aciklama ?? '';

      // Mevcut resimler (URL)
      if (u.resimYollari != null && u.resimYollari!.isNotEmpty) {
        _existingUrls.addAll(u.resimYollari!);
      }
      // Kapak
      if (u.kapakResimYolu != null && u.kapakResimYolu!.isNotEmpty) {
        // Kapak URL ise burada tutulur
        _coverUrl = u.kapakResimYolu;
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

  Future<void> _resimSec() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() {
      _newLocalFiles.addAll(picked.map((e) => File(e.path)));
      // Kapak yoksa ilk seçilen yerel resmi kapak yap
      _coverUrl ??= null;
      _coverLocalPath ??= _newLocalFiles.first.path;
    });
  }

  Future<void> _mevcutUrlSil(String url) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Resmi kaldır'),
        content: const Text('Bu resmi listeden çıkarmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay == true) {
      setState(() {
        _existingUrls.remove(url);
        if (_coverUrl == url) _coverUrl = null;
      });
    }
  }

  Future<void> _yerelResimSil(int index) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Resmi kaldır'),
        content: const Text('Bu resmi listeden çıkarmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay == true) {
      setState(() {
        final path = _newLocalFiles[index].path;
        if (_coverLocalPath == path) _coverLocalPath = null;
        _newLocalFiles.removeAt(index);
      });
    }
  }

  void _kapakYapUrl(String url) {
    setState(() {
      _coverUrl = url;
      _coverLocalPath = null;
    });
  }

  void _kapakYapLocal(String path) {
    setState(() {
      _coverLocalPath = path;
      _coverUrl = null;
    });
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final duzenleme = widget.duzenlenecekUrun != null;

    final urun = Urun(
      docId: widget.duzenlenecekUrun?.docId,
      id: widget.duzenlenecekUrun?.id ?? 0, // ekle'de 0 → servis id üretir
      urunKodu: urunKoduController.text.trim(),
      urunAdi: urunAdiController.text.trim(),
      renk: (_secilenRenkAd ?? '').trim(),
      adet: int.tryParse(adetController.text) ?? 0,
      aciklama: aciklamaController.text.trim(),
      // Resim alanlarını burada doldurmuyoruz; servis güncelleyecek
    );

    setState(() => _kaydediyor = true);
    try {
      if (duzenleme) {
        await urunService.guncelle(
          widget.duzenlenecekUrun!.docId!,
          urun,
          newLocalFiles: _newLocalFiles,
          keepUrls: _existingUrls,
          coverLocalPath: _coverLocalPath,
          coverUrl: _coverUrl,
        );
      } else {
        await urunService.ekle(
          urun,
          localFiles: _newLocalFiles,
          coverLocalPath: _coverLocalPath,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydetme başarısız: $e')));
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
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
        await RenkService.instance.ekle(ad); // sende positional
        if (!mounted) return;
        setState(() => _secilenRenkAd = ad);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Renk eklendi: $ad")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Renk eklenemedi: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.duzenlenecekUrun != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(duzenleme ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'),
        backgroundColor: Renkler.kahveTon,
      ),
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
                    // --- Resim seçim butonu
                    GestureDetector(
                      onTap: _resimSec,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Resim(leri) seçmek için tıklayın'),
                        ),
                      ),
                    ),

                    // --- Grid: Mevcut URL’ler
                    if (_existingUrls.isNotEmpty)
                      _sectionTitle('Yüklü resimler'),
                    if (_existingUrls.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _existingUrls.map((url) {
                          final isCover = _coverUrl == url;
                          return _Thumb(
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                            onRemove: () => _mevcutUrlSil(url),
                            onMakeCover: () => _kapakYapUrl(url),
                            isCover: isCover,
                          );
                        }).toList(),
                      ),

                    // --- Grid: Yeni yerel resimler
                    if (_newLocalFiles.isNotEmpty)
                      _sectionTitle('Yeni seçilenler'),
                    if (_newLocalFiles.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(_newLocalFiles.length, (i) {
                          final f = _newLocalFiles[i];
                          final isCover = _coverLocalPath == f.path;
                          return _Thumb(
                            child: Image.file(
                              f,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                            onRemove: () => _yerelResimSil(i),
                            onMakeCover: () => _kapakYapLocal(f.path),
                            isCover: isCover,
                          );
                        }),
                      ),

                    const SizedBox(height: 20),

                    // --- Form alanları
                    TextFormField(
                      controller: urunKoduController,
                      decoration: const InputDecoration(
                        labelText: 'Ürün Kodu',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: urunAdiController,
                      decoration: const InputDecoration(
                        labelText: 'Ürün Adı',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
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
                      decoration: const InputDecoration(
                        labelText: 'Adet',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Geçersiz sayı';
                        if (n < 0) return 'Negatif olamaz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: aciklamaController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Renkler.kahveTon,
                        ),
                        onPressed: _kaydet,
                        child: Text(
                          duzenleme ? 'Kaydet' : 'Ekle',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            if (_kaydediyor)
              Container(
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback onMakeCover;
  final bool isCover;

  const _Thumb({
    required this.child,
    required this.onRemove,
    required this.onMakeCover,
    required this.isCover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onMakeCover,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 100, height: 100, child: child),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
          if (isCover)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.star, color: Colors.amber),
            ),
        ],
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
      stream: svc.dinle(),
      builder: (context, snap) {
        final renkler = (snap.data ?? [])
            .where((r) => r.ad.trim().isNotEmpty)
            .toList();

        final seen = <String>{};
        final tekil = <RenkItem>[];
        for (final r in renkler) {
          final key = r.ad.trim().toLowerCase();
          if (seen.add(key)) tekil.add(RenkItem(id: r.id, ad: r.ad.trim()));
        }

        final seciliRaw = (seciliAd ?? '').trim();
        final seciliLower = seciliRaw.toLowerCase();

        String? value;
        final match = tekil.firstWhere(
          (r) => r.ad.trim().toLowerCase() == seciliLower,
          orElse: () => RenkItem(id: '', ad: ''),
        );
        if (match.ad.isNotEmpty) {
          value = match.ad;
        } else if (seciliRaw.isNotEmpty) {
          tekil.insert(0, RenkItem(id: '_local_', ad: seciliRaw));
          value = seciliRaw;
        }

        final items = tekil
            .map(
              (r) => DropdownMenuItem<String>(value: r.ad, child: Text(r.ad)),
            )
            .toList();

        if (value != null &&
            items.where((it) => it.value == value).length != 1) {
          value = null;
        }

        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: 'Renk',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: IconButton(
              onPressed: onYeniRenk,
              icon: const Icon(Icons.add),
              tooltip: 'Yeni renk ekle',
            ),
          ),
          items: items,
          onChanged: onDegisti,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Renk seçiniz' : null,
          hint: const Text('Renk seçin'),
        );
      },
    );
  }
}
