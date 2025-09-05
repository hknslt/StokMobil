import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/utils/resim_araclari.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/widgets/tam_ekran_galeri.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';


class UrunGorselSlider extends StatefulWidget {
  final List<String> gorseller;
  final String? kapak;
  final String stableId;
  final Widget Function(String path)? imageBuilder;

  const UrunGorselSlider({
    super.key,
    required this.gorseller,
    required this.kapak,
    required this.stableId,
    this.imageBuilder,
  });

  @override
  State<UrunGorselSlider> createState() => _UrunGorselSliderState();
}

class _UrunGorselSliderState extends State<UrunGorselSlider>
    with AutomaticKeepAliveClientMixin {
  late final PageController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.92, keepPage: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _openFullscreen(int startIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TamEkranGaleri(
          gorseller: widget.gorseller,
          initialIndex: startIndex,
          heroPrefix: 'hero_${widget.stableId}_',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final builder = widget.imageBuilder ?? ((s) => resimWidgeti(s));

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                key: PageStorageKey('pv_${widget.stableId}'),
                controller: _ctrl,
                physics: const PageScrollPhysics(),
                allowImplicitScrolling: true,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.gorseller.length,
                itemBuilder: (context, i) {
                  final p = widget.gorseller[i];
                  final isCover = (widget.kapak ?? '').trim() == p.trim();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _openFullscreen(i),
                          child: Hero(
                            tag: 'hero_${widget.stableId}_$i',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Center(child: builder(p)),
                              ),
                            ),
                          ),
                        ),
                        if (isCover)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Kapak",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (widget.gorseller.length > 1) ...[
                Positioned(
                  left: 0,
                  child: IconButton(
                    onPressed: () {
                      final prev = _index == 0
                          ? widget.gorseller.length - 1
                          : _index - 1;
                      _ctrl.animateToPage(
                        prev,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                    },
                    icon: const Icon(Icons.chevron_left, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {
                      final next = (_index + 1) % widget.gorseller.length;
                      _ctrl.animateToPage(
                        next,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                    },
                    icon: const Icon(Icons.chevron_right, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.gorseller.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              width: active ? 18 : 8,
              decoration: BoxDecoration(
                color: active ? Renkler.kahveTon : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }
}
