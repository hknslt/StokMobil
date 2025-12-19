// lib/services/update_service.dart
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/constants/update_notes.dart'; 
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String _prefKey = 'last_seen_version';
  static Future<void> kontrolEtVeGoster(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final String currentVersion = packageInfo.version; // Örn: "1.0.2"
      final String? lastSeenVersion = prefs.getString(_prefKey);

      // 2. Eğer versiyonlar farklıysa (veya ilk kez yükleniyorsa)
      if (currentVersion != lastSeenVersion) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _UpdateDialog(version: currentVersion),
        );


        await prefs.setString(_prefKey, currentVersion);
      }
    } catch (e) {
      debugPrint("Versiyon kontrol hatası: $e");
    }
  }
}

// Dialog Tasarımı
class _UpdateDialog extends StatelessWidget {
  final String version;
  const _UpdateDialog({required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text("Yenilikler ($version)")),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Capri Uygulaması güncellendi! İşte bu sürümdeki yenilikler:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                GuncellemeNotlari.notlar,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Devam Et", style: TextStyle(fontWeight: FontWeight.bold, color: Renkler.kahveTon)),
        ),
      ],
    );
  }
}