import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'name': name,
        'photoUrl': '',
        'email': email,
        'role': 'both', // default
        'faculty': '',
        'phone': '',
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ✅ konsisten dgn ProfilePage
  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    await _db.collection('users').doc(uid).set({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // optional alias (kalau ada file lama call nama ni)
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
  }) =>
      updatePhotoUrl(uid: uid, photoUrl: photoUrl);

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateMyProfile({
    required String uid,
    required String name,
    required String faculty,
    required String phone,
    String role = 'both', // ✅ default terus both
  }) async {
    final r = role.trim().toLowerCase();
    final safeRole = (r == 'buyer' || r == 'seller' || r == 'both') ? r : 'both';

    await _db.collection('users').doc(uid).set({
      'name': name,
      'faculty': faculty,
      'phone': phone,
      'role': safeRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // OPTIONAL: kalau nanti kau nak guard balik
  Future<String> getUserRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final role = (snap.data()?['role'] ?? 'both').toString().trim().toLowerCase();
    if (role == 'buyer' || role == 'seller' || role == 'both') return role;
    return 'both';
  }
}
