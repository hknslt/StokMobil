import 'dart:io';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/controller/image_manager.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/fullscreen_gallery.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/grup_dropdown.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/image_grid.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/image_picker_tile.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/renk_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/renk_service.dart';
import 'package:capri/services/grup_service.dart';

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
  String? _secilenGrupAd;
  late final ImageManager _im;

  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    final u = widget.duzenlenecekUrun;

    if (u != null) {
      urunKoduController.text = u.urunKodu;
      urunAdiController.text = u.urunAdi;
      _secilenRenkAd = u.renk.isNotEmpty ? u.renk : null;
      _secilenGrupAd = (u.grup != null && u.grup!.isNotEmpty) ? u.grup : null;
      adetController.text = u.adet.toString();
      aciklamaController.text = u.aciklama ?? '';
      _im = ImageManager(
        initialUrls: u.resimYollari,
        initialCover: u.kapakResimYolu,
      );
    } else {
      _im = ImageManager();
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
      final files = picked.map((e) => File(e.path)).toList();
      _im.addFiles(files);
    });
  }

  void _openFullscreenAt(int startIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenGallery(
          images: List<dynamic>.from(_im.images),
          initialIndex: startIndex,
          coverPath: _im.coverPath,
          onMakeCover: (idx) {
            if (!mounted) return;
            setState(() => _im.setCoverByIndex(idx));
          },
          onDelete: (idx) {
            if (!mounted) return;
            setState(() => _im.removeAt(idx));
          },
        ),
      ),
    );
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
        await RenkService.instance.ekle(ad);
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

  Future<void> _yeniGrupEkleDialog() async {
    final adCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yeni Grup Ekle"),
        content: TextField(
          controller: adCtrl,
          decoration: const InputDecoration(
            labelText: "Grup adı (zorunlu)",
            hintText: "Örn: Mutfak",
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
        await GrupService.instance.ekle(ad);
        if (!mounted) return;
        setState(() => _secilenGrupAd = ad);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Grup eklendi: $ad")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Grup eklenemedi: $e")));
      }
    }
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final duzenleme = widget.duzenlenecekUrun != null;

    final newLocalFiles = _im.newLocalFiles();
    final existingUrls = _im.existingUrls();
    final urlsToDelete = _im.urlsToDeleteFrom(
      widget.duzenlenecekUrun?.resimYollari ?? [],
    );

    final urun = Urun(
      docId: widget.duzenlenecekUrun?.docId,
      id: widget.duzenlenecekUrun?.id ?? 0,
      urunKodu: urunKoduController.text.trim(),
      urunAdi: urunAdiController.text.trim(),
      renk: (_secilenRenkAd ?? '').trim(),
      adet: int.tryParse(adetController.text) ?? 0,
      aciklama: aciklamaController.text.trim(),
    );

    setState(() => _kaydediyor = true);
    try {
      if (duzenleme) {
        await urunService.guncelle(
          widget.duzenlenecekUrun!.docId!,
          urun.copyWith(
            resimYollari: existingUrls,
            kapakResimYolu: _im.coverPath,
          ),
          newLocalFiles: newLocalFiles,
          urlsToDelete: urlsToDelete,
        );
      } else {
        await urunService.ekle(
          urun,
          localFiles: newLocalFiles,
          coverLocalPath: _im.coverPath,
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

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.duzenlenecekUrun != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(duzenleme ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'),
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
                    ImagePickerTile(onTap: _resimSec),

                    if (_im.images.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: const Text(
                            'Resimler',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (_im.images.isNotEmpty)
                      ImageGrid(
                        images: _im.images,
                        coverPath: _im.coverPath,
                        onTap: _openFullscreenAt,
                        onRemove: (i) => setState(() => _im.removeAt(i)),
                        onMakeCover: (i) =>
                            setState(() => _im.setCoverByIndex(i)),
                      ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: urunKoduController,
                      decoration: const InputDecoration(
                        labelText: 'Ürün Kodu',
                        labelStyle: TextStyle(color: Renkler.kahveTon),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Renkler.kahveTon,
                            width: 2,
                          ),
                        ),
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
                        labelStyle: TextStyle(color: Renkler.kahveTon),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Renkler.kahveTon,
                            width: 2,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 12),
                    GrupDropdown(
                      seciliAd: _secilenGrupAd,
                      onDegisti: (ad) => setState(() => _secilenGrupAd = ad),
                      onYeniGrup: _yeniGrupEkleDialog,
                    ),
                    const SizedBox(height: 12),
                    RenkDropdown(
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
                        labelStyle: TextStyle(color: Renkler.kahveTon),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Renkler.kahveTon,
                            width: 2,
                          ),
                        ),
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
                        labelStyle: TextStyle(color: Renkler.kahveTon),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Renkler.kahveTon,
                            width: 2,
                          ),
                        ),
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
}
