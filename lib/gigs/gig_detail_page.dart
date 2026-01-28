import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../services/gig_service.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../features/orders/pay_deposit_page.dart';

class GigDetailPage extends StatelessWidget {
  final String gigId;
  const GigDetailPage({super.key, required this.gigId});

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return 0.0;
  }

  bool _toBool(dynamic v) => v == true;

  GeoPoint? _toGeoPoint(dynamic v) => v is GeoPoint ? v : null;

  Widget _stars(double value) {
    final v = value.clamp(0.0, 5.0);
    final full = v.floor();
    final half = (v - full) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star, size: 16, color: Colors.amber);
        if (i == full && half) return const Icon(Icons.star_half, size: 16, color: Colors.amber);
        return const Icon(Icons.star_border, size: 16, color: Colors.amber);
      }),
    );
  }

  Future<(GeoPoint, String)> _getBuyerLocation(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final gp = GeoPoint(pos.latitude, pos.longitude);

    String addr = '';
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        addr = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
          p.country,
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
      }
    } catch (_) {}

    return (gp, addr);
  }

  Future<bool> _showConfirmOrderDialog(
  BuildContext context, {
  required String title,
  required OrderPricePreview preview,
  required bool requiresLocation,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          _rowPrice('Service', preview.serviceAmount),
          if (requiresLocation) ...[
            const SizedBox(height: 6),
            Text('Distance: ${preview.distanceKm.toStringAsFixed(2)} km'),
            Text('Rate: RM ${preview.ratePerKm.toStringAsFixed(2)} / km'),
            _rowPrice('Transport', preview.transportCharge),
          ],
          const Divider(height: 18),
          _rowPrice('TOTAL', preview.totalAmount, bold: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
      ],
    ),
  );
  return ok == true;
}

Widget _rowPrice(String label, double val, {bool bold = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text('RM ${val.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    final gigs = GigService();
    final orders = OrderService();
    final users = UserService();

    return Scaffold(
      appBar: AppBar(title: const Text('Service Detail')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: gigs.getGig(gigId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data();
          if (data == null) return const Center(child: Text('Gig not found'));

          final title = (data['title'] ?? '').toString();
          final desc = (data['description'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          final price = _toDouble(data['price']);
          final sellerId = (data['sellerId'] ?? '').toString();

          final requiresLocation = _toBool(data['requiresLocation']);
          final sellerLocation = _toGeoPoint(data['sellerLocation']);
          final sellerAddress = (data['sellerAddress'] ?? '').toString();
          final ratePerKm = _toDouble(data['ratePerKm'] ?? 2.0);

          final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final isMyGig = myId.isNotEmpty && myId == sellerId;

          final depositAmount = _toDouble(data['depositAmount'] ?? 0.0);
          final sellerQrUrl = (data['qrImageUrl'] ?? '').toString();
          final paymentRef = orders.generatePaymentRef();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Chip(label: Text(category.isEmpty ? 'General' : category)),
                      const Spacer(),
                      Text(
                        'RM ${price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(desc),
                  const SizedBox(height: 16),

                  if (requiresLocation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        border: Border.all(color: Colors.orange.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'On-site service required.\nTransport: RM ${ratePerKm.toStringAsFixed(2)} per km',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),

                  if (sellerId.isNotEmpty)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: users.watchUserProfile(sellerId),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final u = userSnap.data!.data() ?? {};
                        final name = (u['name'] ?? 'Seller').toString();
                        final faculty = (u['faculty'] ?? '').toString();
                        final phone = (u['phone'] ?? '').toString();
                        final photoUrl = (u['photoUrl'] ?? '').toString();

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: orders.streamSellerReviewItems(sellerId, limit: 50),
                          builder: (context, rateSnap) {
                            final docs = rateSnap.data?.docs ?? [];
                            double avg = 0.0;
                            int count = 0;
                            double sum = 0.0;
                            for (final d in docs) {
                              final rv = _toDouble(d.data()['rating']);
                              if (rv > 0) {
                                sum += rv;
                                count++;
                              }
                            }
                            if (count > 0) avg = sum / count;

                            return Card(
                              margin: const EdgeInsets.only(top: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              if (faculty.isNotEmpty)
                                                Text('Faculty: $faculty', style: TextStyle(color: Colors.grey.shade700)),
                                              if (phone.isNotEmpty)
                                                Text('Phone: $phone', style: TextStyle(color: Colors.grey.shade700)),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Flexible(child: _stars(avg)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    count > 0 ? '${avg.toStringAsFixed(1)} ($count)' : 'No rating yet',
                                                    style: TextStyle(color: Colors.grey.shade700),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Latest Reviews', style: TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                      stream: orders.streamSellerLatestReviews(sellerId, limit: 3),
                                      builder: (context, revSnap) {
                                        if (!revSnap.hasData) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 6),
                                            child: LinearProgressIndicator(),
                                          );
                                        }
                                        final reviews = revSnap.data!.docs;
                                        if (reviews.isEmpty) {
                                          return Text('No reviews yet.', style: TextStyle(color: Colors.grey.shade700));
                                        }

                                        return Column(
                                          children: reviews.map((d) {
                                            final r = d.data();
                                            final rating = _toDouble(r['rating']);
                                            final review = (r['review'] ?? '').toString().trim();
                                            return Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(child: _stars(rating)),
                                                      const SizedBox(width: 6),
                                                      Text(rating.toStringAsFixed(1),
                                                          style: TextStyle(color: Colors.grey.shade700)),
                                                    ],
                                                  ),
                                                  if (review.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(review),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                     onPressed: isMyGig
    ? null
    : () async {
        try {
          GeoPoint? buyerLoc;
          String buyerAddr = '';

          // 1) If requiresLocation -> get buyer current location
          if (requiresLocation) {
            if (sellerLocation == null) {
              throw Exception('Seller location missing. Ask seller to update gig.');
            }

            final confirmLoc = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Service Location'),
                content: const Text('Use your current location for this on-site service?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Use Current Location'),
                  ),
                ],
              ),
            );

            if (confirmLoc != true) return;

            final res = await _getBuyerLocation(context);
            buyerLoc = res.$1;
            buyerAddr = res.$2;
          }

          // 2) Preview price (service + transport)
          final preview = orders.previewPrice(
            serviceAmount: price,
            requiresLocation: requiresLocation,
            sellerLocation: sellerLocation,
            ratePerKm: ratePerKm,
            serviceLocation: buyerLoc,
          );

          // 3) Confirm order dialog (shows breakdown)
          final ok = await _showConfirmOrderDialog(
            context,
            title: title,
            preview: preview,
            requiresLocation: requiresLocation,
          );

          if (!ok) return;


          final depositAmount = _toDouble(data['depositAmount'] ?? 0.0);
          final sellerQrUrl = (data['qrImageUrl'] ?? '').toString();
          final paymentRef = orders.generatePaymentRef();

          // 4) Create order only AFTER confirm
          final orderId = await orders.createOrderFromGig(
            gigId: gigId,
            gigTitle: title,
            amount: price,
            sellerId: sellerId,
            requiresLocation: requiresLocation,
            sellerLocation: sellerLocation,
            sellerAddress: sellerAddress,
            ratePerKm: ratePerKm,
            serviceLocation: buyerLoc,
            serviceAddress: buyerAddr,

            // NEW
            depositAmount: depositAmount,
            sellerQrUrl: sellerQrUrl,
            paymentRef: paymentRef,
          );

          // ✅ (optional) snack bar
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Order created: $orderId')),
  );
}

// ✅ Navigate to PayDepositPage
if (context.mounted) {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PayDepositPage(
        orderId: orderId,
        gigTitle: title,
        depositAmount: depositAmount,
        paymentRef: paymentRef,
        sellerQrUrl: sellerQrUrl,
      ),
    ),
  );
}
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e')),
            );
          }
        }
      },

                      child: Text(isMyGig ? 'This is your gig' : 'Order (Base RM ${price.toStringAsFixed(2)})'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
