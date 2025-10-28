
import 'dart:io';
import 'package:capri/core/Color/Colors.dart';
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

  // --- Görsel durumları ---
  String? _coverUrl; 
  String? _coverLocalPathIfNew;
  List<String> _galleryUrls =
      []; 


  late final Set<String>
  _originalHttpAll; 


  final List<File> _newLocalFiles = [];

  @override
  void initState() {
    super.initState();
    final u = widget.urun;
    urunKoduController = TextEditingController(text: u.urunKodu);
    urunAdiController = TextEditingController(text: u.urunAdi);
    renkController = TextEditingController(text: u.renk);
    adetController = TextEditingController(text: u.adet.toString());
    aciklamaController = TextEditingController(text: u.aciklama ?? '');

 
    _coverUrl = u.kapakResimYolu;
    final galeri = List<String>.from(u.resimYollari ?? const []);
  
    if (_coverUrl != null) {
      galeri.removeWhere((e) => e == _coverUrl);
    }
    _galleryUrls = galeri;

 
    _originalHttpAll = {
      if (u.kapakResimYolu != null && u.kapakResimYolu!.startsWith('http'))
        u.kapakResimYolu!,
      ...(u.resimYollari ?? const []).where((e) => e.startsWith('http')),
    }.toSet();
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

  // ---- Resim seçme ----
  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isEmpty) return;

    final files = pickedFiles.map((f) => File(f.path)).toList();
    setState(() {
      for (final f in files) {
        _newLocalFiles.add(f);

        _galleryUrls.add(f.path);
      }

      if (_coverUrl == null && _galleryUrls.isNotEmpty) {
        final first = _galleryUrls.removeAt(0);
        _coverUrl = first;
        _coverLocalPathIfNew = first.startsWith('http') ? null : first;
      }
    });
  }

  void _removeImage(String url) {
    setState(() {
      if (_coverUrl == url) {
        if (!url.startsWith('http')) {
          _newLocalFiles.removeWhere((f) => f.path == url);
        }

        _coverUrl = null;
        _coverLocalPathIfNew = null;

        if (_galleryUrls.isNotEmpty) {
          final next = _galleryUrls.removeAt(0);
          _coverUrl = next;
          _coverLocalPathIfNew = next.startsWith('http') ? null : next;
        }
        return;
      }

      final ix = _galleryUrls.indexOf(url);
      if (ix >= 0) {
        if (!url.startsWith('http')) {
          _newLocalFiles.removeWhere((f) => f.path == url);
        }
        _galleryUrls.removeAt(ix);
      }
    });
  }

  void _makeCover(String url) {
    setState(() {
      final prevCover = _coverUrl;

      _galleryUrls.removeWhere((e) => e == url);

      if (prevCover != null && prevCover != url) {
        if (!_galleryUrls.contains(prevCover)) {
          _galleryUrls.insert(0, prevCover);
        }
      }

      _coverUrl = url;
      _coverLocalPathIfNew = url.startsWith('http') ? null : url;
    });
  }

  // ---- Güncelle ----
  Future<void> urunGuncelle() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final docId = widget.urun.docId;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu üründe Firestore docId yok.')),
      );
      return;
    }
    final finalCoverHttp = _coverUrl?.startsWith('http') == true
        ? _coverUrl
        : null;
    final finalGalleryHttp = _galleryUrls
        .where((e) => e.startsWith('http'))
        .toList();

    final finalKeep = <String>{
      ...finalGalleryHttp,
      if (finalCoverHttp != null) finalCoverHttp,
    };
    final urlsToDelete = _originalHttpAll.difference(finalKeep).toList();

    final guncelUrun = widget.urun.copyWith(
      urunKodu: urunKoduController.text.trim(),
      urunAdi: urunAdiController.text.trim(),
      renk: renkController.text.trim(),
      adet: int.tryParse(adetController.text.trim()) ?? widget.urun.adet,
      aciklama: aciklamaController.text.trim(),
      resimYollari: finalGalleryHttp,
      kapakResimYolu: finalCoverHttp,
    );

    try {
      await urunService.guncelle(
        docId,
        guncelUrun,
        newLocalFiles: _newLocalFiles,
        urlsToDelete: urlsToDelete,
        coverLocalPath: _coverLocalPathIfNew,
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
    final allForGrid = <String>[
      if (_coverUrl != null) _coverUrl!,
      ..._galleryUrls,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ürün Düzenle"),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allForGrid.map((url) {
                  final isCover = _coverUrl == url;
                  return GestureDetector(
                    onDoubleTap: () => _makeCover(url),
                    child: Stack(
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
                        if (isCover)
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Kapak',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _removeImage(url),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
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
