import 'package:flutter/material.dart';

class ImageThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback onMakeCover;
  final VoidCallback? onTap;
  final bool isCover;
  final String? heroTag;

  const ImageThumb({
    super.key,
    required this.child,
    required this.onRemove,
    required this.onMakeCover,
    required this.isCover,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        height: 100,
        child: heroTag != null ? Hero(tag: heroTag!, child: child) : child,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onMakeCover,
      child: Stack(
        children: [
          content,
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
          if (isCover)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.star, color: Colors.amber),
            ),
        ],
      ),
    );
  }
}
