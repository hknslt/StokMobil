import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_detay_sayfasi.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/fiyat_listesi_service.dart';
import 'package:capri/services/urun_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SiparisKarti extends StatelessWidget {
  final SiparisModel siparis;
  final bool isBusy;
  final Function(SiparisModel) onSevkiyataOnayla;
  final Function(SiparisModel) onUretimeOnayla;
  final Function(SiparisModel) onReddet;

  const SiparisKarti({
    super.key,
    required this.siparis,
    required this.isBusy,
    required this.onSevkiyataOnayla,
    required this.onUretimeOnayla,
    required this.onReddet,
  });

  @override
  Widget build(BuildContext context) {
    final musteri = siparis.musteri;
    final tarihStr = DateFormat('dd.MM.yyyy – HH:mm').format(siparis.tarih);
    final musteriAdi = musteri.firmaAdi?.isNotEmpty == true
        ? musteri.firmaAdi!
        : musteri.yetkili ?? "";

    final stokKontrollu =
        siparis.durum == SiparisDurumu.beklemede ||
        siparis.durum == SiparisDurumu.uretimde;

    final netToplam = (siparis.netTutar ?? siparis.toplamTutar);
    final kdvOrani =
        (siparis.kdvOrani ?? FiyatListesiService.instance.aktifKdv);
    final brutToplam =
        (siparis.brutTutar ??
        (netToplam * (1 + kdvOrani / 100)).roundToDouble());

    // --- YENİ MANTIK: Stok Analizi ---
    return FutureBuilder<Map<int, StokDetay>>(
      future: UrunService().analizEtStokDurumu(siparis.urunler),
      builder: (context, snapshot) {
        final analizSonucu = snapshot.data ?? {};

        bool genelStokYeterli = true;

        if (stokKontrollu && snapshot.hasData) {
          genelStokYeterli = !analizSonucu.values.any(
            (d) => d.durum == StokDurumu.yetersiz,
          );
        }

        final bool kritikUrunVar = analizSonucu.values.any(
          (d) => d.durum == StokDurumu.kritik,
        );

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          musteriAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.open_in_new, color: Renkler.kahveTon),
                        tooltip: "Detay Sayfası",
                        onPressed: isBusy
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SiparisDetaySayfasi(siparis: siparis),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tarih: $tarihStr"),
                      Text(
                        "İşlem Tarih: ${siparis.islemeTarihi != null ? DateFormat('dd.MM.yyyy').format(siparis.islemeTarihi!) : '-'}",
                      ),
                      Row(
                        children: [
                          Text("Ürün Sayısı: ${siparis.urunler.length}"),
                          const SizedBox(width: 8),
                          if (stokKontrollu)
                            snapshot.connectionState == ConnectionState.waiting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    genelStokYeterli
                                        ? "Stok Var"
                                        : "Stok Yetersiz",
                                    style: TextStyle(
                                      color: genelStokYeterli
                                          ? (kritikUrunVar
                                                ? Colors.orange
                                                : Colors.green)
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ],
                      ),
                      Text(
                        "Toplam: ₺${brutToplam.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  children: siparis.urunler.map((urun) {
                    final id = int.tryParse(urun.id) ?? -1;
                    final detay = analizSonucu[id];

                    Color renk = Colors.grey;

                    if (stokKontrollu && detay != null) {
                      switch (detay.durum) {
                        case StokDurumu.yeterli:
                          renk = Colors.green;
                          break;
                        case StokDurumu.kritik:
                          renk = Colors.orangeAccent;
                          break;
                        case StokDurumu.yetersiz:
                          renk = Colors.red;
                          break;
                      }
                    }

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: renk,
                        radius: 16,
                        child: Text(
                          "${urun.adet}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        "${urun.urunAdi} ${urun.renk != null ? "(${urun.renk})" : ""}",
                        style: TextStyle(
                          color: stokKontrollu ? renk : Colors.black87,
                          fontWeight:
                              (stokKontrollu &&
                                  detay?.durum != StokDurumu.yeterli)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        "Stok: ${detay?.mevcutStok ?? '...'} | Birim: ₺${urun.birimFiyat}",
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                      trailing: Text(
                        "₺${urun.toplamFiyat.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // --- EKLENDİ: SİPARİŞ DURUM ETİKETİ ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: SiparisDurumEtiketi(durum: siparis.durum),
                ),

                const SizedBox(height: 8),

                // --- BUTONLAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (siparis.durum == SiparisDurumu.beklemede) ...[
                      if (genelStokYeterli && snapshot.hasData)
                        _buildActionButton(
                          icon: Icons.local_shipping,
                          label: "Sevkiyat Onayı",
                          color: Colors.green,
                          onPressed: () => onSevkiyataOnayla(siparis),
                        )
                      else
                        _buildActionButton(
                          icon: Icons.build,
                          label: "Üretim Onayı",
                          color: Colors.green,
                          onPressed: () => onUretimeOnayla(siparis),
                        ),
                      const SizedBox(width: 8),
                    ] else if (siparis.durum == SiparisDurumu.uretimde) ...[
                      if (genelStokYeterli && snapshot.hasData)
                        _buildActionButton(
                          icon: Icons.local_shipping,
                          label: "Sevkiyat Onayı",
                          color: Colors.green,
                          onPressed: () => onSevkiyataOnayla(siparis),
                        )
                      else
                        TextButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.more_time, color: Colors.grey),
                          label: const Text(
                            "Üretim Bekleniyor",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],

                    if (siparis.durum != SiparisDurumu.tamamlandi &&
                        siparis.durum != SiparisDurumu.reddedildi)
                      IconButton(
                        onPressed: isBusy ? null : () => onReddet(siparis),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Reddet",
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, color: Colors.white),
      label: Text(
        isBusy ? "İşleniyor..." : label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
