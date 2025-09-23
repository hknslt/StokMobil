import 'package:capri/core/Color/Colors.dart';
import 'package:flutter/material.dart';

class HakkindaSayfasi extends StatelessWidget {
  const HakkindaSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hakkında"),
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
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- Uygulama Logosu ---
            Column(
              children: [
                Image.asset(
                  "assets/images/capri_logo.png",
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Capri Stok & Sipariş Takip",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Stok ve sipariş süreçlerini kolaylaştıran, "
                  "işletme için modern ve kullanıcı dostu bir uygulama.",
                  style: TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            // --- Alt Kısım: Geliştirici logosu ---
            Column(
              children: [
                const Text(
                  "Hakan Salt",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Image.asset(
                  "assets/images/dev_logo.png",
                  width: 90,
                  height: 90,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
