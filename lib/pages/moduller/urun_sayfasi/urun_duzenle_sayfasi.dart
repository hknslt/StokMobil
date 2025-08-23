import 'package:flutter/material.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';

class UrunDuzenleSayfasi extends StatefulWidget {
  /// Eski yerlere uyumluluk için duruyor ama kullanılmıyor
  final int? index;
  final Urun urun;

  const UrunDuzenleSayfasi({
    super.key,
    this.index,
    required this.urun,
  });

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

  @override
  void initState() {
    super.initState();
    final u = widget.urun;
    urunKoduController = TextEditingController(text: u.urunKodu);
    urunAdiController  = TextEditingController(text: u.urunAdi);
    renkController     = TextEditingController(text: u.renk);
    adetController     = TextEditingController(text: u.adet.toString());
    aciklamaController = TextEditingController(text: u.aciklama ?? '');
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

  Future<void> urunGuncelle() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final docId = widget.urun.docId;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu üründe Firestore docId yok.')),
      );
      return;
    }

    final guncelUrun = widget.urun.copyWith(
      urunKodu: urunKoduController.text.trim(),
      urunAdi:  urunAdiController.text.trim(),
      renk:     renkController.text.trim(),
      adet:     int.tryParse(adetController.text.trim()) ?? widget.urun.adet,
      aciklama: aciklamaController.text.trim(),
    );

    try {
      await urunService.guncelle(docId, guncelUrun);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme başarısız: $e')),
      );
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
                validator: (v) => (v == null || v.isEmpty) ? "Ürün kodu boş olamaz" : null,
              ),
              TextFormField(
                controller: urunAdiController,
                decoration: const InputDecoration(labelText: "Ürün Adı"),
                validator: (v) => (v == null || v.isEmpty) ? "Ürün adı boş olamaz" : null,
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
