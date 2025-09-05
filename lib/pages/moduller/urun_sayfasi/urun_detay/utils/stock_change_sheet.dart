import 'package:flutter/material.dart';

class StockChangeInput {
  final int delta;
  StockChangeInput(this.delta);
}

Future<StockChangeInput?> showStockChangeSheet(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final deltaCtrl = TextEditingController();

  void nudge(int d) {
    final cur = int.tryParse(deltaCtrl.text.replaceAll('+', '').trim()) ?? 0;
    final next = cur + d;
    // 0 yazmanın anlamı yok; yine de kullanıcı isterse düzeltebilir.
    deltaCtrl.text = (next >= 0 ? '+$next' : '$next');
  }

  return showModalBottomSheet<StockChangeInput>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final inset = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42, height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Text('Stok Güncelle', style: Theme.of(ctx).textTheme.titleMedium),

              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ElevatedButton(onPressed: () => nudge(1), child: const Text('+1')),
                  ElevatedButton(onPressed: () => nudge(5), child: const Text('+5')),
                  ElevatedButton(onPressed: () => nudge(-1), child: const Text('-1')),
                  ElevatedButton(onPressed: () => nudge(-5), child: const Text('-5')),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: deltaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Değişim (örn. +3, -2)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final raw = (v ?? '').trim().replaceAll('+','');
                  final n = int.tryParse(raw);
                  if (n == null || n == 0) return 'Geçerli bir sayı girin (0 olamaz)';
                  return null;
                },
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final raw = deltaCtrl.text.trim().replaceAll('+','');
                    final n = int.parse(raw);
                    Navigator.pop(ctx, StockChangeInput(n));
                  },
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
