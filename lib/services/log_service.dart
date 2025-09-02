// lib/services/log_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogService {
  LogService._();
  static final LogService instance = LogService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _cachedActor;
  String? _cachedUid;

  // --- küçük yardımcılar ---
  String? _s(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  Map<String, dynamic> _sanitizeTarget(Map<String, dynamic> target) {
    final t = Map<String, dynamic>.from(target);
    // her zaman string'e çek
    if (t.containsKey('docId')) t['docId'] = _s(t['docId']);
    if (t.containsKey('type')) t['type'] = _s(t['type']) ?? 'unknown';
    return t;
  }

  Map<String, dynamic> _sanitizeMeta(Map<String, dynamic>? meta) {
    if (meta == null) return {};
    final out = <String, dynamic>{};
    meta.forEach((k, v) {
      // sayılar & bool olduğu gibi, diğer her şey .toString()
      if (v == null || v is num || v is bool) {
        out[k] = v;
      } else if (v is String) {
        out[k] = v;
      } else if (v is DateTime) {
        out[k] = Timestamp.fromDate(v);
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

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

    final emailDb = _s(d['email']);
    final usernameDb = _s(d['username']);
    final firstNameDb = _s(d['firstName']);
    final lastNameDb = _s(d['lastName']);
    final roleDb = _s(d['role']) ?? 'user';

    final emailAuth = _s(u.email);
    final usernameFromEmail = emailAuth?.split('@').first;

    final actor = {
      'uid': _s(u.uid),
      'email': emailDb ?? emailAuth,
      'username': usernameDb ?? usernameFromEmail ?? '',
      'firstName': firstNameDb ?? '',
      'lastName': lastNameDb ?? '',
      'role': roleDb,
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
    try {
      final actor = await _getActor();
      final safeTarget = _sanitizeTarget(target);
      final safeMeta = _sanitizeMeta(meta);

      await _db.collection('logs').add({
        'ts': FieldValue.serverTimestamp(),     // server clock
        'clientTs': Timestamp.now(),            // istemci saati (debug için)
        'action': _s(action) ?? 'unknown',
        'actor': actor,                         // { uid, email, username, ... }
        'target': safeTarget,                   // { type, docId, ... } (docId: String)
        'meta': safeMeta,                       // serbest alanlar (sanitize)
      });
    } catch (_) {
      // log yazımı hiç bir zaman app'i düşürmesin
      // (gerekirse buraya debugPrint ekleyebilirsin)
    }
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
        'docId': urunDocId,            // sanitizeTarget bunu string'e çevirecek
        if (urunId != null) 'urunId': urunId,
        if (urunAdi != null) 'urunAdi': urunAdi,
      },
      meta: meta,
    );
  }
}
