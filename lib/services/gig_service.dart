import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGigs({String? category}) {
    Query<Map<String, dynamic>> q =
        _db.collection('gigs').where('active', isEqualTo: true);

    if (category != null && category != 'All') {
      q = q.where('category', isEqualTo: category);
    }

    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyGigs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('gigs')
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createGig({
    required String title,
    required String description,
    required String category,
    required double price,
    required String sellerId,

    // ✅ new fields
    required bool requiresLocation,
    GeoPoint? sellerLocation,
    String sellerAddress = '',
    double ratePerKm = 2.0,

    double depositAmount = 0.0,
    String qrImageUrl = '',

  }) async {
    final doc = _db.collection('gigs').doc();

    await doc.set({
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'sellerId': sellerId,

      'requiresLocation': requiresLocation,
      'sellerLocation': sellerLocation, // can be null if not required
      'sellerAddress': sellerAddress,
      'ratePerKm': ratePerKm,

      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'depositAmount': depositAmount,
      'qrImageUrl': qrImageUrl,
      
    });

    return doc.id;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGig(String gigId) {
    return _db.collection('gigs').doc(gigId).get();
  }

  Future<void> updateGig({
    required String gigId,
    required String title,
    required String description,
    required String category,
    required double price,
    // optional update location fields if you want later
  }) async {
    await _db.collection('gigs').doc(gigId).update({
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleGigActive({
    required String gigId,
    required bool active,
  }) async {
    await _db.collection('gigs').doc(gigId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGig(String gigId) async {
    await _db.collection('gigs').doc(gigId).delete();
  }
}
