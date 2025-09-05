import 'dart:io';
import 'package:flutter/material.dart';

/// Yol tipine göre uygun Image widget'ı döndürür.
/// Varsayılan: BoxFit.contain
Widget resimWidgeti(
  String path, {
  BoxFit fit = BoxFit.contain,
  double? width,
  double? height,
}) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, size: 42, color: Colors.grey),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
  final f = File(path);
  if (!f.existsSync()) {
    return const Icon(Icons.image_not_supported, size: 42, color: Colors.grey);
  }
  return Image.file(
    f,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) =>
        const Icon(Icons.broken_image_outlined, size: 42, color: Colors.grey),
  );
}
