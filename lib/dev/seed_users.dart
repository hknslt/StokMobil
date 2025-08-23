// lib/dev/seed_users.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Bir kerelik kullanıcı seed'i.
/// Çalıştırdıktan sonra bu çağrıyı KALDIR.
Future<void> runUserSeeding() async {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;

  // Seed verileri (senin listedeki kullanıcılar)
  final users = [
    {
      'firstName': 'Hakan',
      'lastName' : 'Salt',
      'username' : '1',
      'email'    : 'hakan@mail.com',
      'password' : '111111',     // <-- min 6 karakter
      'role'     : 'admin',
    },
    {
      'firstName': 'Enes',
      'lastName' : 'Salt',
      'username' : '2',
      'email'    : 'enes@mail.com',
      'password' : '222222',
      'role'     : 'uretim',
    },
    {
      'firstName': 'Ahmet',
      'lastName' : 'Salt',
      'username' : '3',
      'email'    : 'ahmet@mail.com',
      'password' : '333333',
      'role'     : 'pazarlamaci',
    },
    {
      'firstName': 'Mustafa',
      'lastName' : 'Salt',
      'username' : '4',
      'email'    : 'mustafa@mail.com',
      'password' : '444444',
      'role'     : 'sevkiyat',
    },
  ];

  // Varsa çıkış yap (temiz başlangıç)
  try { await auth.signOut(); } catch (_) {}

  for (final u in users) {
    final email = (u['email'] as String).trim();
    final password = u['password'] as String;

    try {
      // 1) Auth'ta oluştur ve o kullanıcı olarak oturum açılır
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // 2) Firestore profil belgesi
      final username = (u['username'] as String).trim();
      await db.collection('users').doc(uid).set({
        'email'        : email,
        'username'     : username,
        'usernameLower': username.toLowerCase(),
        'firstName'    : u['firstName'],
        'lastName'     : u['lastName'],
        'role'         : u['role'],
        'createdAt'    : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Devam etmeden önce çıkış
      await auth.signOut();
    } on FirebaseAuthException catch (e) {
      // Zaten varsa devam et (örn: e-mail already in use)
      if (e.code == 'email-already-in-use') {
        // Yine de profil belgesi yoksa oluşturmak isteyebilirsin:
        // Ancak uid'yi bilmediğimiz için burada atlıyoruz.
        // (Seed'i bir kez çalıştırmak yeterli.)
        continue;
      } else {
        rethrow;
      }
    }
  }
}
