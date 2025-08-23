import 'package:flutter/material.dart';

class HakkindaSayfasi extends StatelessWidget {
  const HakkindaSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hakkında")),
      body: const Center(child: Text("Uygulama hakkında bilgiler")),
    );
  }
}
