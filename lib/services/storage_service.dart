import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';


class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile picture user
  /// Path: profile_photos/{uid}/profile.jpg
  Future<String> uploadProfilePhoto(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final uid = user.uid;

    // ✅ PATH CONSISTENT DENGAN RULES
    final ref = _storage
        .ref()
        .child('profile_photos')
        .child(uid)
        .child('profile.jpg');

    // ✅ upload file
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
      ),
    );

    // ✅ get download URL
    final url = await ref.getDownloadURL();
    return url;
  }

    /// Upload seller QR for a gig
  /// Path: seller_qr/{uid}/{gigId}.png/jpg
  Future<String> uploadSellerQr({
    required String gigId,
    required File file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final uid = user.uid;

    // detect ext (simple)
    final path = file.path.toLowerCase();
    final isPng = path.endsWith('.png');
    final ext = isPng ? 'png' : 'jpg';
    final contentType = isPng ? 'image/png' : 'image/jpeg';

    final ref = _storage
        .ref()
        .child('seller_qr')
        .child(uid)
        .child('$gigId.$ext');

    await ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );

    return await ref.getDownloadURL();
  }


}
