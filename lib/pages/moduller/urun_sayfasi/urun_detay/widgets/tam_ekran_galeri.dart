import 'dart:io';
import 'package:flutter/material.dart';

class TamEkranGaleri extends StatefulWidget {
  final List<String> gorseller;
  final int initialIndex;
  final String heroPrefix;

  const TamEkranGaleri({
    super.key,
    required this.gorseller,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<TamEkranGaleri> createState() => _TamEkranGaleriState();
}

class _TamEkranGaleriState extends State<TamEkranGaleri> {
  late final PageController _ctrl;
  int _index = 0;
  bool _isZooming = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex, keepPage: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _fullImageFor(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
        loadingBuilder: (c, child, prog) =>
            prog == null ? child : const Center(child: CircularProgressIndicator()),
      );
    } else {
      final f = File(path);
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
              itemCount: widget.gorseller.length,
              itemBuilder: (context, i) {
                final path = widget.gorseller[i];
                return Center(
                  child: Hero(
                    tag: '${widget.heroPrefix}$i',
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      onInteractionStart: (_) => setState(() => _isZooming = true),
                      onInteractionEnd: (_) => setState(() => _isZooming = false),
                      child: _fullImageFor(path),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
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
                    '${_index + 1} / ${widget.gorseller.length}',
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
