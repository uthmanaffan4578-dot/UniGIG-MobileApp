import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // =========================
  // ✅ Notification helper
  // =========================
  Map<String, dynamic> _notifDoc({
    required String toUserId,
    required String title,
    required String message,
    required String orderId,
    required String type,
  }) {
    return {
      'toUserId': toUserId,
      'title': title,
      'message': message,
      'orderId': orderId,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };
  }

  double _distanceKm(GeoPoint a, GeoPoint b) {
    const R = 6371.0;
    double toRad(double d) => d * (math.pi / 180.0);

    final dLat = toRad(b.latitude - a.latitude);
    final dLng = toRad(b.longitude - a.longitude);

    final lat1 = toRad(a.latitude);
    final lat2 = toRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyOrders() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return _db
        .collection('orders')
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createOrderFromGig({
    required String gigId,
    required String gigTitle,
    required double amount,
    required String sellerId,
    required bool requiresLocation,
    required GeoPoint? sellerLocation,
    required String sellerAddress,
    required double ratePerKm,
    GeoPoint? serviceLocation,
    String serviceAddress = '',
    double depositAmount = 0.0,
    String sellerQrUrl = '',
    String paymentRef = '',

  }) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;

    if (requiresLocation) {
      if (sellerLocation == null) throw Exception('Seller location not set.');
      if (serviceLocation == null) throw Exception('Buyer location required.');
    }

    double distKm = 0.0;
    double transport = 0.0;
    if (requiresLocation && sellerLocation != null && serviceLocation != null) {
      distKm = _distanceKm(sellerLocation, serviceLocation);
      transport = distKm * ratePerKm;
    }

    final total = amount + transport;

    final doc = _db.collection('orders').doc();
    await doc.set({
      'gigId': gigId,
      'gigTitle': gigTitle,
      'amount': amount,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'participants': [buyerId, sellerId],

      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': buyerId,

      'requiresLocation': requiresLocation,
      'serviceLocation': serviceLocation,
      'serviceAddress': serviceAddress,
      'sellerLocation': sellerLocation,
      'sellerAddress': sellerAddress,

      // =========================
      // ✅ Deposit payment fields
      // =========================
      'depositAmount': depositAmount, // kita set dari GigDetailPage
      'paymentRef': paymentRef,
      'sellerQrUrl': sellerQrUrl,
      'paymentStatus': 'AWAITING_RECEIPT', // AWAITING_RECEIPT / PENDING_VERIFICATION / VERIFIED / REJECTED
      'paymentReceiptUrl': '',
      'paymentReceiptUploadedAt': null,
      'paymentReceiptUploadedBy': '',
      'paymentVerifiedAt': null,
      'paymentVerifiedBy': '',
      'paymentRejectReason': '',

      'distanceKm': distKm,
      'ratePerKm': ratePerKm,
      'transportCharge': transport,
      'totalAmount': total,

      // ✅ proof fields
      'proofImageUrl': '',
      'proofUploadedAt': null,
      'proofUploadedBy': '',

      // rating fields
      'rating': null,
      'review': '',
      'ratedAt': null,
    });

    // ✅ Seller notification: new pending order
    await _db.collection('notifications').add(
          _notifDoc(
            toUserId: sellerId,
            title: 'New Order 📩',
            message: 'You received a new order for "$gigTitle".',
            orderId: doc.id,
            type: 'order_pending',
          ),
        );

    return doc.id;
  }

  Future<void> updateStatus({
    required String orderId,
    required String newStatus,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data() as Map<String, dynamic>;
      final buyerId = (data['buyerId'] ?? '').toString();
      final sellerId = (data['sellerId'] ?? '').toString();
      final gigTitle = (data['gigTitle'] ?? 'Job').toString();
      final oldStatus = (data['status'] ?? '').toString();

      tx.update(orderRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // ✅ Buyer notification: seller accepted order
      if (newStatus == 'accepted' && oldStatus != 'accepted') {
        tx.set(
          _db.collection('notifications').doc(),
          _notifDoc(
            toUserId: buyerId,
            title: 'Order Accepted ✅',
            message: 'Seller accepted your order for "$gigTitle".',
            orderId: orderId,
            type: 'order_accepted',
          ),
        );
      }
    });
  }

  // ✅ Buyer confirms completion (enables rating rules)
  Future<void> completeOrder({required String orderId}) async {
    await updateStatus(orderId: orderId, newStatus: 'completed');
  }

  Future<void> cancelOrder({required String orderId}) async {
    await updateStatus(orderId: orderId, newStatus: 'cancelled');
  }

  Future<void> rejectOrder({required String orderId}) async {
    await updateStatus(orderId: orderId, newStatus: 'rejected');
  }

  Future<void> rateOrder({
    required String orderId,
    required int rating,
    String review = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data() as Map<String, dynamic>;
      final buyerId = (data['buyerId'] ?? '').toString();
      final sellerId = (data['sellerId'] ?? '').toString();
      final gigTitle = (data['gigTitle'] ?? 'Job').toString();
      final status = (data['status'] ?? '').toString();

      if (buyerId != uid) throw Exception('Only buyer can rate this order.');
      if (status != 'completed') throw Exception('You can only rate after order is completed.');
      if (data['rating'] != null) throw Exception('Order already rated.');

      final r = rating.clamp(1, 5);

      tx.update(orderRef, {
        'rating': r,
        'review': review,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      final reviewRef = _db
          .collection('seller_reviews')
          .doc(sellerId)
          .collection('items')
          .doc(orderId);

      tx.set(reviewRef, {
        'orderId': orderId,
        'sellerId': sellerId,
        'buyerId': buyerId,
        'rating': r,
        'review': review,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Seller notification: buyer rated
      tx.set(
        _db.collection('notifications').doc(),
        _notifDoc(
          toUserId: sellerId,
          title: 'New Rating ⭐',
          message: 'Buyer rated "$gigTitle" ($r/5).',
          orderId: orderId,
          type: 'order_rated',
        ),
      );
    });
  }

  // =========================
  // ✅ Proof upload + delivered
  // =========================

  Future<String> uploadOrderProofImage({
    required String orderId,
    required XFile file,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ext = file.name.split('.').last.toLowerCase();
    final safeExt = (ext.isEmpty) ? 'jpg' : ext;

    final ref = _storage
        .ref()
        .child('order_proofs')
        .child(orderId)
        .child('${DateTime.now().millisecondsSinceEpoch}.$safeExt');

    final task = await ref.putFile(
      File(file.path),
      SettableMetadata(contentType: 'image/$safeExt'),
    );

    final url = await task.ref.getDownloadURL();

    await _db.collection('orders').doc(orderId).update({
      'proofImageUrl': url,
      'proofUploadedAt': FieldValue.serverTimestamp(),
      'proofUploadedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    return url;
  }

  Future<void> markDeliveredWithProof({
    required String orderId,
    required XFile proofImage,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final orderRef = _db.collection('orders').doc(orderId);

    final url = await uploadOrderProofImage(orderId: orderId, file: proofImage);

    await orderRef.update({
      'status': 'delivered',
      'proofImageUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    // ✅ Buyer notification: delivered
    final snap = await orderRef.get();
    final data = snap.data() as Map<String, dynamic>;
    final buyerId = (data['buyerId'] ?? '').toString();
    final gigTitle = (data['gigTitle'] ?? 'Job').toString();

    await _db.collection('notifications').add(
          _notifDoc(
            toUserId: buyerId,
            title: 'Order Delivered 📦',
            message: 'Seller delivered proof for "$gigTitle". Please review.',
            orderId: orderId,
            type: 'order_delivered',
          ),
        );
  }

    // =========================
  // ✅ PAYMENT (Deposit) flow
  // =========================

  String generatePaymentRef() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = math.Random();
    final code = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
    return 'UG-$code';
  }

  Future<String> uploadPaymentReceipt({
    required String orderId,
    required XFile file,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ext = file.name.split('.').last.toLowerCase();
    final safeExt = (ext.isEmpty) ? 'jpg' : ext;

    final ref = _storage
        .ref()
        .child('payment_receipts')
        .child(orderId)
        .child('${DateTime.now().millisecondsSinceEpoch}.$safeExt');

    final task = await ref.putFile(
      File(file.path),
      SettableMetadata(contentType: 'image/$safeExt'),
    );

    final url = await task.ref.getDownloadURL();

    await _db.collection('orders').doc(orderId).update({
      'paymentReceiptUrl': url,
      'paymentReceiptUploadedAt': FieldValue.serverTimestamp(),
      'paymentReceiptUploadedBy': uid,
      'paymentStatus': 'PENDING_VERIFICATION',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    return url;
  }

  Future<void> verifyPayment({
    required String orderId,
    required bool approve,
    String? reason,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');

      final data = snap.data() as Map<String, dynamic>;
      final buyerId = (data['buyerId'] ?? '').toString();
      final sellerId = (data['sellerId'] ?? '').toString();
      final gigTitle = (data['gigTitle'] ?? 'Job').toString();

      // only seller should verify (basic check)
      if (sellerId != uid) throw Exception('Only seller can verify payment.');

      tx.update(orderRef, {
        'paymentStatus': approve ? 'VERIFIED' : 'REJECTED',
        'paymentVerifiedAt': FieldValue.serverTimestamp(),
        'paymentVerifiedBy': uid,
        if (!approve) 'paymentRejectReason': reason ?? 'Invalid receipt',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // notify buyer
      tx.set(
        _db.collection('notifications').doc(),
        _notifDoc(
          toUserId: buyerId,
          title: approve ? 'Deposit Verified ✅' : 'Deposit Rejected ❌',
          message: approve
              ? 'Your deposit for "$gigTitle" has been verified.'
              : 'Your deposit for "$gigTitle" was rejected. ${reason ?? ''}'.trim(),
          orderId: orderId,
          type: approve ? 'deposit_verified' : 'deposit_rejected',
        ),
      );
    });
  }


  // =========================
  // PUBLIC streams (reviews)
  // =========================
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSellerReviewItems(
    String sellerId, {
    int limit = 50,
  }) {
    return _db
        .collection('seller_reviews')
        .doc(sellerId)
        .collection('items')
        .orderBy('ratedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSellerLatestReviews(
    String sellerId, {
    int limit = 3,
  }) {
    return _db
        .collection('seller_reviews')
        .doc(sellerId)
        .collection('items')
        .orderBy('ratedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}

// =========================
// Price Preview model
// =========================
class OrderPricePreview {
  final double serviceAmount;
  final double distanceKm;
  final double ratePerKm;
  final double transportCharge;
  final double totalAmount;

  const OrderPricePreview({
    required this.serviceAmount,
    required this.distanceKm,
    required this.ratePerKm,
    required this.transportCharge,
    required this.totalAmount,
  });
}

extension OrderPricing on OrderService {
  OrderPricePreview previewPrice({
    required double serviceAmount,
    required bool requiresLocation,
    required GeoPoint? sellerLocation,
    required double ratePerKm,
    required GeoPoint? serviceLocation,
  }) {
    if (requiresLocation) {
      if (sellerLocation == null) throw Exception('Seller location not set.');
      if (serviceLocation == null) throw Exception('Buyer location required.');
    }

    double distKm = 0.0;
    double transport = 0.0;

    if (requiresLocation && sellerLocation != null && serviceLocation != null) {
      distKm = _distanceKm(sellerLocation, serviceLocation);
      transport = distKm * ratePerKm;
    }

    final total = serviceAmount + transport;

    return OrderPricePreview(
      serviceAmount: serviceAmount,
      distanceKm: distKm,
      ratePerKm: ratePerKm,
      transportCharge: transport,
      totalAmount: total,
    );
  }
}
