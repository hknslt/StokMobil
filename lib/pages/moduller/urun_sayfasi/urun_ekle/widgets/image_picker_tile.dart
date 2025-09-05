import 'package:flutter/material.dart';

class ImagePickerTile extends StatelessWidget {
  final VoidCallback onTap;
  const ImagePickerTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Resim(leri) seçmek için tıklayın'),
        ),
      ),
    );
  }
}
