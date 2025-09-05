import 'dart:io';

/// String (URL) ya da File (yerel) tipindeki görsellerle çalışan yardımcılar.
String pathOf(dynamic img) => img is File ? img.path : img as String;

class ImageManager {
  final List<dynamic> images = <dynamic>[];
  String? coverPath;

  ImageManager({List<String>? initialUrls, String? initialCover}) {
    if (initialUrls != null) images.addAll(initialUrls);
    coverPath = initialCover;
    _ensureCover();
  }

  void addFiles(List<File> files) {
    if (files.isEmpty) return;
    images.addAll(files);
    _ensureCover();
  }

  void addUrls(List<String> urls) {
    if (urls.isEmpty) return;
    images.addAll(urls);
    _ensureCover();
  }

  void removeAt(int index) {
    if (index < 0 || index >= images.length) return;
    final removed = images.removeAt(index);
    final removedPath = pathOf(removed);
    if (coverPath == removedPath) {
      coverPath = images.isNotEmpty ? pathOf(images.first) : null;
    }
  }

  void remove(dynamic image) {
    final idx = images.indexOf(image);
    if (idx == -1) return;
    removeAt(idx);
  }

  void setCoverByIndex(int index) {
    if (index < 0 || index >= images.length) return;
    coverPath = pathOf(images[index]);
  }

  void setCoverByImage(dynamic image) => coverPath = pathOf(image);

  List<File> newLocalFiles() => images.whereType<File>().toList();
  List<String> existingUrls() => images.whereType<String>().toList();

  /// Önceden kayıtlı URL'ler içinden, listede artık bulunmayanları bulur.
  List<String> urlsToDeleteFrom(List<String> previousUrls) {
    final now = existingUrls().toSet();
    return previousUrls.where((u) => !now.contains(u)).toList();
  }

  void _ensureCover() {
    if (coverPath == null && images.isNotEmpty) {
      coverPath = pathOf(images.first);
    }
  }
}
