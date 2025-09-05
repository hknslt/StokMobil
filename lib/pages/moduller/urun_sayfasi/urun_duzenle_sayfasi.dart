// lib/screens/urun_duzenle_sayfasi.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';
import 'package:image_picker/image_picker.dart';

class UrunDuzenleSayfasi extends StatefulWidget {
  final int? index;
  final Urun urun;

  const UrunDuzenleSayfasi({super.key, this.index, required this.urun});

  @override
  State<UrunDuzenleSayfasi> createState() => _UrunDuzenleSayfasiState();
}

class _UrunDuzenleSayfasiState extends State<UrunDuzenleSayfasi> {
  final UrunService urunService = UrunService();

  late final TextEditingController urunKoduController;
  late final TextEditingController urunAdiController;
  late final TextEditingController renkController;
  late final TextEditingController adetController;
  late final TextEditingController aciklamaController;

  final _formKey = GlobalKey<FormState>();

  // Resim yönetim listeleri
  List<String> _allImageUrls = [];
  List<File> _newLocalFiles = [];

  @override
  void initState() {
    super.initState();
    final u = widget.urun;
    urunKoduController = TextEditingController(text: u.urunKodu);
    urunAdiController = TextEditingController(text: u.urunAdi);
    renkController = TextEditingController(text: u.renk);
    adetController = TextEditingController(text: u.adet.toString());
    aciklamaController = TextEditingController(text: u.aciklama ?? '');

    // Eski resimleri listeye ekle
    if (u.resimYollari != null) {
      _allImageUrls = List.from(u.resimYollari!);
    }
  }

  @override
  void dispose() {
    urunKoduController.dispose();
    urunAdiController.dispose();
    renkController.dispose();
    adetController.dispose();
    aciklamaController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isEmpty) return;

    final files = pickedFiles.map((f) => File(f.path)).toList();
    setState(() {
      _newLocalFiles.addAll(files);
      // Yeni dosyaları URL'ler listesine geçici olarak ekle
      _allImageUrls.addAll(files.map((e) => e.path));
    });
  }

  void _removeImage(String url) {
    setState(() {
      final index = _allImageUrls.indexOf(url);
      if (index >= 0) {
        // Eğer silinen resim yeni yüklenmiş bir resimse, newLocalFiles listesinden de çıkar
        if (_newLocalFiles.any((f) => f.path == url)) {
          _newLocalFiles.removeWhere((f) => f.path == url);
        }
        _allImageUrls.removeAt(index);
      }
    });
  }

  Future<void> urunGuncelle() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final docId = widget.urun.docId;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu üründe Firestore docId yok.')),
      );
      return;
    }

    // Silinen URL'leri hesapla
    final urlsToDelete =
        widget.urun.resimYollari
            ?.where((url) => !_allImageUrls.contains(url))
            .toList() ??
        [];

    final guncelUrun = widget.urun.copyWith(
      urunKodu: urunKoduController.text.trim(),
      urunAdi: urunAdiController.text.trim(),
      renk: renkController.text.trim(),
      adet: int.tryParse(adetController.text.trim()) ?? widget.urun.adet,
      aciklama: aciklamaController.text.trim(),
      resimYollari: _allImageUrls,
      kapakResimYolu: _allImageUrls.isNotEmpty ? _allImageUrls.first : null,
    );

    try {
      await urunService.guncelle(
        docId,
        guncelUrun,
        newLocalFiles: _newLocalFiles,
        urlsToDelete: urlsToDelete,
        // Bu satırı sil
        // coverLocalPath: guncelUrun.kapakResimYolu,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ürün Düzenle")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: urunKoduController,
                decoration: const InputDecoration(labelText: "Ürün Kodu"),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Ürün kodu boş olamaz" : null,
              ),
              TextFormField(
                controller: urunAdiController,
                decoration: const InputDecoration(labelText: "Ürün Adı"),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Ürün adı boş olamaz" : null,
              ),
              TextFormField(
                controller: renkController,
                decoration: const InputDecoration(labelText: "Renk"),
              ),
              TextFormField(
                controller: adetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Adet"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Adet giriniz";
                  final adet = int.tryParse(value);
                  if (adet == null || adet < 0) return "Geçerli bir adet girin";
                  return null;
                },
              ),
              TextFormField(
                controller: aciklamaController,
                decoration: const InputDecoration(labelText: "Açıklama"),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              // Resim önizleme alanı ve silme butonu
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allImageUrls.map((url) {
                  return Stack(
                    children: [
                      url.startsWith('http')
                          ? Image.network(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(url),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _removeImage(url),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Yeni resim ekleme butonu
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Resim Ekle'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: urunGuncelle,
                child: const Text("Güncelle"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
