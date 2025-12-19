import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// KAYIT: email+password -> Auth, ardından users/{uid} profili
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? username,          // boşsa email'den türetiriz
    String firstName = '',
    String lastName = '',
    String role = 'user',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uname = (username?.trim().isNotEmpty == true
        ? username!.trim()
        : email.split('@').first);

    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email.trim(),
      'username': uname,
      'usernameLower': uname.toLowerCase(),
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return cred;
  }

  /// GİRİŞ: input email veya kullanıcı adı olabilir
  Future<UserCredential> signInWithEmailOrUsername({
    required String input,
    required String password,
  }) async {
    final trimmed = input.trim();
    String? email;

    if (trimmed.contains('@')) {
      email = trimmed.toLowerCase();
    } else {
      // username -> email bul (case-insensitive için usernameLower kullan)
      final q = await _db
          .collection('users')
          .where('usernameLower', isEqualTo: trimmed.toLowerCase())
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Kullanıcı adı bulunamadı',
        );
      }

      email = q.docs.first.data()['email'] as String?;
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Kullanıcıya ait e-posta bulunamadı',
        );
      }
    }

    final cred = await _auth.signInWithEmailAndPassword(
      email: email!,
      password: password,
    );

    // Profil belgesi yoksa oluştur (özellikle dış kaynaklı kayıtlar için faydalı)
    await _ensureUserDoc(cred.user!);
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _db.collection('users').doc(u.uid).get();
    return doc.data();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// İlk kez giriş yapan kullanıcı için profil belgesi üret
  Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final fallback = user.email?.split('@').first ?? user.uid;
      await ref.set({
        'email': user.email,
        'username': fallback,
        'usernameLower': fallback.toLowerCase(),
        'firstName': '',
        'lastName': '',
        'role': 'user', // varsayılan rol
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// (Opsiyonel) Auth state -> profil modeli stream (UI için kullanışlı)
  /// Bunu kullanmak istersen UserModel.fromMap ile dönüştür.
  Stream<Map<String, dynamic>?> currentUserProfileStream() {
    return _auth.authStateChanges().asyncMap((u) async {
      if (u == null) return null;
      final doc = await _db.collection('users').doc(u.uid).get();
      return doc.data();
    });
  }
}
