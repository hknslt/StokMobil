import 'dart:io';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/controller/image_manager.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/widgets/image_thumb.dart';
import 'package:flutter/material.dart';


class ImageGrid extends StatelessWidget {
  final List<dynamic> images; // String URL veya File
  final String? coverPath;
  final void Function(int index) onTap;
  final void Function(int index) onRemove;
  final void Function(int index) onMakeCover;

  const ImageGrid({
    super.key,
    required this.images,
    required this.coverPath,
    required this.onTap,
    required this.onRemove,
    required this.onMakeCover,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images.asMap().entries.map((e) {
        final i = e.key;
        final img = e.value;
        final p = pathOf(img);
        final isCover = p == coverPath;

        final thumb = img is String
            ? Image.network(p, fit: BoxFit.cover, width: 100, height: 100)
            : Image.file(img as File, fit: BoxFit.cover, width: 100, height: 100);

        return ImageThumb(
          heroTag: p,
          child: thumb,
          onTap: () => onTap(i),
          onRemove: () => onRemove(i),
          onMakeCover: () => onMakeCover(i),
          isCover: isCover,
        );
      }).toList(),
    );
  }
}
