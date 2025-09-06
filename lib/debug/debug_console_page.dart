import 'package:flutter/material.dart';
import 'package:capri/debug/dlog.dart';

class DebugConsolePage extends StatefulWidget {
  const DebugConsolePage({super.key});

  @override
  State<DebugConsolePage> createState() => _DebugConsolePageState();
}

class _DebugConsolePageState extends State<DebugConsolePage> {
  @override
  Widget build(BuildContext context) {
    final lines = DLog.dump().reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hata Konsolu'),
        actions: [
          IconButton(
            tooltip: 'Temizle',
            onPressed: () { DLog.clear(); setState(() {}); },
            icon: const Icon(Icons.delete_sweep),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          lines.isEmpty ? 'Henüz log yok.' : lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
