import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_olu%C5%9Fturma/siparis_musteri_widget.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_olu%C5%9Fturma/siparis_tarih_aciklama_sayfasi.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_olu%C5%9Fturma/siparis_urun_sec_sayfasi.dart';

import 'siparis_fiyatlandirma_sayfasi.dart';
import 'siparis_ozet_sayfasi.dart';

class SiparisOlusturSayfasi extends StatefulWidget {
  const SiparisOlusturSayfasi({super.key});

  @override
  State<SiparisOlusturSayfasi> createState() => _SiparisOlusturSayfasiState();
}

class _SiparisOlusturSayfasiState extends State<SiparisOlusturSayfasi> {
  int _aktifAdim = 0;

  // Müşteri Bilgileri
  final TextEditingController firmaAdi = TextEditingController();
  final TextEditingController yetkili = TextEditingController();
  final TextEditingController telefon = TextEditingController();
  final TextEditingController adres = TextEditingController();
  MusteriModel? secilenMusteri;
  // Tarih & Açıklama
  DateTime? islemeTarihi;
  String? siparisAciklama;

  // Ürünler
  List<SiparisUrunModel> secilenUrunler = [];

  void ileri() {
    if (_aktifAdim < 4) {
      setState(() => _aktifAdim++);
    }
  }

  void geri() {
    if (_aktifAdim > 0) {
      setState(() => _aktifAdim--);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget aktifWidget;

    switch (_aktifAdim) {
      case 0:
        aktifWidget = SiparisMusteriWidget(
          firmaAdiController: firmaAdi,
          yetkiliController: yetkili,
          telefonController: telefon,
          adresController: adres,
          secilenMusteri: secilenMusteri,
          onMusteriSecildi: (musteri) {
            setState(() {
              secilenMusteri = musteri;
              firmaAdi.text = musteri.firmaAdi ?? '';
              yetkili.text = musteri.yetkili ?? '';
              telefon.text = musteri.telefon ?? '';
              adres.text = musteri.adres ?? '';
            });
          },
          onIleri: ileri,
        );
        break;

      case 1:
        aktifWidget = SiparisUrunSecSayfasi(
          onNext: (urunler) {
            setState(() {
              secilenUrunler = urunler;
              ileri();
            });
          },
          onBack: geri,
        );

        break;

      case 2:
        aktifWidget = SiparisFiyatlandirmaSayfasi(
          secilenUrunler: secilenUrunler,
          onNext: (guncellenmisListe) {
            setState(() {
              secilenUrunler = guncellenmisListe;
              ileri();
            });
          },
          onBack: geri,
        );
        break;

      case 3:
        aktifWidget = SiparisTarihAciklamaSayfasi(
          baslangicTarih: islemeTarihi,
          baslangicAciklama: siparisAciklama,
          onBack: geri,
          onNext: (tarih, aciklama) {
            setState(() {
              islemeTarihi = tarih;
              siparisAciklama = aciklama;
              ileri();
            });
          },
        );
        break;

      case 4:
        aktifWidget = SiparisOzetSayfasi(
          musteri: MusteriModel(
            id: secilenMusteri?.id ?? "",
            firmaAdi: firmaAdi.text,
            yetkili: yetkili.text,
            telefon: telefon.text,
            adres: adres.text,
          ),
          urunler: secilenUrunler,
          islemeTarihi: islemeTarihi, // Özet ekranına da göndereceğiz
          siparisAciklama: siparisAciklama,
          onBack: geri,
        );
        break;

      default:
        aktifWidget = const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sipariş Oluştur"),
        centerTitle: true,
        backgroundColor: Renkler.kahveTon,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          StepperHeaderWidget(adim: _aktifAdim),
          const SizedBox(height: 12),
          Expanded(child: aktifWidget),
        ],
      ),
    );
  }
}

class StepperHeaderWidget extends StatelessWidget {
  final int adim;
  const StepperHeaderWidget({super.key, required this.adim});

  @override
  Widget build(BuildContext context) {
    const adimlar = ["Müşteri", "Ürünler", "Fiyat", "Tarih", "Özet"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(adimlar.length, (index) {
          final aktif = index == adim;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: aktif ? Renkler.kahveTon : Colors.grey,
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adimlar[index],
                  style: TextStyle(
                    fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
