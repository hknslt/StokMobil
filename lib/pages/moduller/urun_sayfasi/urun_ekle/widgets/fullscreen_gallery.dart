import 'dart:io';
import 'package:capri/pages/moduller/urun_sayfasi/urun_ekle/controller/image_manager.dart';
import 'package:flutter/material.dart';


class FullscreenGallery extends StatefulWidget {
  final List<dynamic> images; // String URL + File karışık
  final int initialIndex;
  final String? coverPath;
  final void Function(int index)? onDelete;
  final void Function(int index)? onMakeCover;

  const FullscreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.coverPath,
    this.onDelete,
    this.onMakeCover,
  });

  @override
  State<FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<FullscreenGallery> {
  late List<dynamic> _imgs;
  late final PageController _ctrl;
  int _index = 0;
  bool _isZooming = false;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    _imgs = List<dynamic>.from(widget.images);
    _index = widget.initialIndex.clamp(0, _imgs.isEmpty ? 0 : _imgs.length - 1);
    _ctrl = PageController(initialPage: _index, keepPage: true);
    _coverPath = widget.coverPath;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _imgWidget(dynamic img) {
    final p = pathOf(img);
    if (p.startsWith('http')) {
      return Image.network(
        p,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
        loadingBuilder: (c, child, prog) =>
            prog == null ? child : const Center(child: CircularProgressIndicator()),
      );
    }
    final f = img is File ? img : File(p);
    if (!f.existsSync()) {
      return const Icon(Icons.image_not_supported, color: Colors.white70, size: 48);
    }
    return Image.file(
      f,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
    );
  }

  void _deleteCurrent() {
    if (_imgs.isEmpty) return;
    final idx = _index;
    final removedPath = pathOf(_imgs[idx]);

    widget.onDelete?.call(idx);
    _imgs.removeAt(idx);

    if (_coverPath == removedPath) {
      _coverPath = _imgs.isNotEmpty ? pathOf(_imgs.first) : null;
    }

    if (_imgs.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index = (_index >= _imgs.length) ? _imgs.length - 1 : _index;
      _ctrl.jumpToPage(_index);
    });
  }

  void _makeCoverCurrent() {
    if (_imgs.isEmpty) return;
    final idx = _index;
    _coverPath = pathOf(_imgs[idx]);
    widget.onMakeCover?.call(idx);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              physics: _isZooming
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _imgs.length,
              itemBuilder: (context, i) {
                final p = pathOf(_imgs[i]);
                return Center(
                  child: Hero(
                    tag: p,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      onInteractionStart: (_) => setState(() => _isZooming = true),
                      onInteractionEnd: (_) => setState(() => _isZooming = false),
                      child: _imgWidget(_imgs[i]),
                    ),
                  ),
                );
              },
            ),

            if (_imgs.length > 1) ...[
              Positioned(
                left: 0,
                child: IconButton(
                  onPressed: () {
                    final prev = _index == 0 ? _imgs.length - 1 : _index - 1;
                    _ctrl.animateToPage(prev,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  },
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  onPressed: () {
                    final next = (_index + 1) % _imgs.length;
                    _ctrl.animateToPage(next,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  },
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                ),
              ),
            ],

            // Üstte: kapat / kapak / sil
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Kapat',
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _makeCoverCurrent,
                    icon: Icon(
                      _imgs.isNotEmpty && _coverPath == pathOf(_imgs[_index])
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                    ),
                    tooltip: 'Kapak yap',
                  ),
                  IconButton(
                    onPressed: _deleteCurrent,
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Sil',
                  ),
                ],
              ),
            ),

            // Alt sayaç
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_index + 1} / ${_imgs.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
