import 'package:flutter/material.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: const Center(child: Text("Ayarlar sayfası içeriği buraya gelecek")),
    );
  }
}
