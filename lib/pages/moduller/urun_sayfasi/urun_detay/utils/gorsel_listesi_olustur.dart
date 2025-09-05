import 'package:capri/core/models/urun_model.dart';

/// Kapak + diğer görselleri tekrarsız ve kapak en başta olacak şekilde verir.
List<String> gorselListesiOlustur(Urun u) {
  final set = <String>{};
  final list = <String>[];

  final cover = (u.kapakResimYolu ?? '').trim();
  if (cover.isNotEmpty) {
    set.add(cover);
    list.add(cover);
  }

  final others = u.resimYollari ?? const <String>[];
  for (final p in others) {
    final pp = p.trim();
    if (pp.isEmpty) continue;
    if (set.add(pp)) list.add(pp);
  }
  return list;
}
