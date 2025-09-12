import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/Color/Colors.dart';

class SiparisTarihAciklamaSayfasi extends StatefulWidget {
  final DateTime? baslangicTarih;
  final String? baslangicAciklama;
  final Function(DateTime? tarih, String? aciklama) onNext;
  final VoidCallback onBack;

  const SiparisTarihAciklamaSayfasi({
    super.key,
    this.baslangicTarih,
    this.baslangicAciklama,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SiparisTarihAciklamaSayfasi> createState() =>
      _SiparisTarihAciklamaSayfasiState();
}

class _SiparisTarihAciklamaSayfasiState
    extends State<SiparisTarihAciklamaSayfasi> {
  DateTime? secilenTarih;
  final TextEditingController aciklamaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    secilenTarih = widget.baslangicTarih ?? DateTime.now();
    aciklamaController.text = widget.baslangicAciklama ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final tarihStr = secilenTarih != null
        ? DateFormat("dd.MM.yyyy").format(secilenTarih!)
        : "Tarih seçilmedi";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Başlık
                  Text(
                    "İşleme Alınma Tarihi Seçin",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Renkler.kahveTon,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Takvim
                  // Takvim
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      height: 300, // fazla yer kaplamasın
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Renkler.kahveTon, // seçilen günün rengi
                            onPrimary: Colors.white, // seçilen günün yazısı
                            surface: Colors.white, // takvim arka planı
                            onSurface: Colors.black, // normal günlerin yazısı
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: secilenTarih ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 5),
                          onDateChanged: (yeniTarih) {
                            setState(() {
                              secilenTarih = yeniTarih;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Seçilen tarihi göster
                  Text(
                    "Seçilen Tarih: $tarihStr",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Açıklama alanı
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: aciklamaController,
                        decoration: const InputDecoration(
                          labelText: "Sipariş Açıklaması",
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    "Geri",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onNext(secilenTarih, aciklamaController.text);
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    "İleri",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Renkler.kahveTon,
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
    );
  }
}
