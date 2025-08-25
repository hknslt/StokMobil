// lib/services/log_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogService {
  LogService._();
  static final LogService instance = LogService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// users/{uid} -> { firstName, lastName, role, username, email } çeker (cache’ler).
  Map<String, dynamic>? _cachedActor;
  String? _cachedUid;

  Future<Map<String, dynamic>> _getActor() async {
    final u = _auth.currentUser;
    if (u == null) {
      return {
        'uid': null,
        'email': null,
        'username': null,
        'firstName': null,
        'lastName': null,
        'role': null,
      };
    }
    if (_cachedActor != null && _cachedUid == u.uid) {
      return _cachedActor!;
    }

    final doc = await _db.collection('users').doc(u.uid).get();
    final d = doc.data() ?? {};
    final actor = {
      'uid': u.uid,
      'email': d['email'] ?? u.email,
      'username': d['username'] ?? (u.email?.split('@').first ?? ''),
      'firstName': d['firstName'] ?? '',
      'lastName': d['lastName'] ?? '',
      'role': d['role'] ?? 'user',
    };
    _cachedActor = actor;
    _cachedUid = u.uid;
    return actor;
  }

  /// Genel amaçlı log yazıcı
  Future<void> log({
    required String action,
    required Map<String, dynamic> target, // {type, docId, ...}
    Map<String, dynamic>? meta,
  }) async {
    final actor = await _getActor();
    await _db.collection('logs').add({
      'ts': FieldValue.serverTimestamp(),
      'action': action,          // ör: "siparis_eklendi"
      'actor': actor,            // { uid, email, username, firstName, lastName, role }
      'target': target,          // { type: "siparis"|"urun"|"stok"|..., docId, ... }
      'meta': meta ?? {},        // serbest ekstra alanlar
    });
  }

  // --- Sık kullanılan yardımcılar ---

  Future<void> logSiparis({
    required String action,
    required String siparisId,
    Map<String, dynamic>? meta,
  }) {
    return log(
      action: action,
      target: {'type': 'siparis', 'docId': siparisId},
      meta: meta,
    );
  }

  Future<void> logUrun({
    required String action,
    required String? urunDocId,
    int? urunId,
    String? urunAdi,
    Map<String, dynamic>? meta,
  }) {
    return log(
      action: action,
      target: {
        'type': 'urun',
        'docId': urunDocId,
        if (urunId != null) 'urunId': urunId,
        if (urunAdi != null) 'urunAdi': urunAdi,
      },
      meta: meta,
    );
  }
}
