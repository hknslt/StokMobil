import 'package:flutter/material.dart';
import 'package:capri/services/renk_service.dart';

class RenkSecField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  const RenkSecField({super.key, this.initialValue, this.onChanged});

  @override
  State<RenkSecField> createState() => _RenkSecFieldState();
}

class _RenkSecFieldState extends State<RenkSecField> {
  static const _placeholder = "— Seç —";
  static const _yeniRenk = "+ Yeni Renk…";

  String? _secili;

  @override
  void initState() {
    super.initState();
    _secili = (widget.initialValue ?? "").trim().isEmpty ? null : widget.initialValue!.trim();
  }

  Future<void> _yeniRenkEkleDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni Renk Ekle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Renk adı",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ekle")),
        ],
      ),
    );

    if (ok == true) {
      final ad = ctrl.text.trim();
      if (ad.isEmpty) return;
      await RenkService.instance.ekle(ad); // servis zaten dup kontrolü yapıyor
      setState(() => _secili = ad);
      widget.onChanged?.call(ad);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: RenkService.instance.dinleAdlar(),
      builder: (context, snap) {
        final liste = (snap.data ?? []);

        // items’ı güvenli kur: placeholder + (gerekirse seçili-ama-listede-olmayan) + renkler + "+ Yeni Renk…"
        final items = <String>[_placeholder];

        final seciliVarVeListedeYok =
            (_secili != null && _secili!.isNotEmpty && !liste.contains(_secili!));
        if (seciliVarVeListedeYok) {
          items.add(_secili!); // ephemerally add
        }

        items.addAll(liste);
        items.add(_yeniRenk);

        // value her zaman items içinde olmalı
        final value = (_secili == null || _secili!.isEmpty) ? _placeholder : _secili;

        return DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e),
                  ))
              .toList(),
          onChanged: (val) async {
            if (val == null) return;

            if (val == _yeniRenk) {
              await _yeniRenkEkleDialog();
              return;
            }

            if (val == _placeholder) {
              setState(() => _secili = null);
              widget.onChanged?.call('');
              return;
            }

            setState(() => _secili = val);
            widget.onChanged?.call(val);
          },
          decoration: const InputDecoration(
            labelText: "Renk",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          isExpanded: true,
        );
      },
    );
  }
}
