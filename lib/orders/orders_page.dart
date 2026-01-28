import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/order_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _service = OrderService();
  final _picker = ImagePicker();

  Future<XFile?> _pickProofImage() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
  }

  // ---------- UI helpers ----------
  Color _chipColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'delivered':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _prettyStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return 0.0;
  }

  Future<bool> _confirm(BuildContext context, String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- Rating ----------
  Widget _starsRow({
    required int value,
    required void Function(int) onSelect,
  }) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        children: List.generate(5, (i) {
          final idx = i + 1;
          final selected = idx <= value;

          return IconButton(
            onPressed: () => onSelect(idx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 28,
            icon: Icon(
              selected ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showRateDialog({
    required BuildContext context,
    required String orderId,
  }) async {
    int stars = 5;
    final reviewCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rate Seller'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _starsRow(
                value: stars,
                onSelect: (v) => setState(() => stars = v),
              ),
              TextField(
                controller: reviewCtrl,
                decoration: const InputDecoration(
                  labelText: 'Review (optional)',
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _service.rateOrder(
          orderId: orderId,
          rating: stars,
          review: reviewCtrl.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks! Rating submitted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  // ✅ premium breakdown subtitle
  Widget _priceBreakdown(_OrderRow o) {
    final hasTransport = o.transportCharge > 0.0;

    Widget line(String text, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12.2,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line('Service: RM ${o.amount.toStringAsFixed(2)}', Icons.receipt_long),
        if (hasTransport)
          line(
            'Transport: RM ${o.transportCharge.toStringAsFixed(2)} (${o.distanceKm.toStringAsFixed(2)} km)',
            Icons.local_shipping_outlined,
          ),
        if (o.serviceAddress.trim().isNotEmpty)
          line('Location: ${o.serviceAddress}', Icons.location_on_outlined),
      ],
    );
  }

  // ---------- actions ----------
  void _showActions({
    required BuildContext context,
    required String orderId,
    required String status,
    required bool isSeller,
    required bool isBuyer,
    required bool alreadyRated,
    required String proofImageUrl,
    required String paymentStatus,
    required String paymentReceiptUrl,
    required double depositAmount,

  }) {
    if (status == 'cancelled' || status == 'rejected') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order'),
          content: const Text('No actions available for this status.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final actions = <_ActionItem>[];

    final needsDeposit = depositAmount > 0;
    final depositPending = paymentStatus == 'PENDING_VERIFICATION';
    final depositVerified = paymentStatus == 'VERIFIED';

// Seller: verify deposit first (if applicable)
if (isSeller && needsDeposit && depositPending) {
    actions.add(_ActionItem('Approve Deposit', 'approve_deposit'));
    actions.add(_ActionItem('Reject Deposit', 'reject_deposit'));
}

    // Seller flow
    if (isSeller) {
      if (status == 'pending') {
        if (!needsDeposit || depositVerified) {
           actions.add(_ActionItem('Accept', 'accepted'));
            }
            actions.add(_ActionItem('Reject', 'rejected'));
            }
          if (status == 'accepted') actions.add(_ActionItem('Start Work', 'in_progress'));
          if (status == 'in_progress') {
            actions.add(_ActionItem('Mark Delivered (Upload Proof)', 'delivered'));
      }
    }

    // Buyer flow
    if (isBuyer) {
      if (status == 'pending') actions.add(_ActionItem('Cancel Order', 'cancelled'));
      if (status == 'delivered') actions.add(_ActionItem('Complete Order', 'completed'));
      if (status == 'completed' && !alreadyRated) {
        actions.add(_ActionItem('Rate Seller', 'rate'));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order Actions',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    _StatusPill(
                      label: _prettyStatus(status),
                      color: _chipColor(status),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ Deposit receipt preview
if (depositAmount > 0 && paymentReceiptUrl.trim().isNotEmpty) ...[
  Row(
    children: [
      const Expanded(
        child: Text(
          'Deposit Receipt',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      _StatusPill(
        label: paymentStatus.isEmpty ? 'Deposit' : paymentStatus,
        color: (paymentStatus == 'VERIFIED')
            ? Colors.green
            : (paymentStatus == 'REJECTED')
                ? Colors.red
                : Colors.orange,
      ),
    ],
  ),
  const SizedBox(height: 8),
  ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.network(
      paymentReceiptUrl,
      height: 190,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 190,
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        child: const Text('Unable to load receipt image'),
      ),
    ),
  ),
  const SizedBox(height: 12),
],


                // proof preview
                if (proofImageUrl.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      proofImageUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 190,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const Text('Unable to load proof image'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // actions buttons
                ...actions.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(a.value == 'rate' ? Icons.star : Icons.sync),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          a.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);

                        if (a.value == 'approve_deposit') {
  try {
    await _service.verifyPayment(orderId: orderId, approve: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit approved.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
  return;
}

if (a.value == 'reject_deposit') {
  final ok = await _confirm(context, 'Reject Deposit', 'Reject this deposit receipt?');
  if (!ok) return;

  try {
    await _service.verifyPayment(orderId: orderId, approve: false, reason: 'Receipt not valid');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit rejected.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
  return;
}

                        if (a.value == 'rate') {
                          await _showRateDialog(context: context, orderId: orderId);
                          return;
                        }

                        // ✅ delivered requires proof image upload
                        if (a.value == 'delivered') {
                          final img = await _pickProofImage();
                          if (img == null) return;

                          try {
                            await _service.markDeliveredWithProof(orderId: orderId, proofImage: img);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Delivered with proof uploaded.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                          return;
                        }

                        final needConfirm =
                            a.value == 'completed' || a.value == 'cancelled' || a.value == 'rejected';

                        if (needConfirm) {
                          final ok = await _confirm(
                            context,
                            a.label,
                            'Are you sure you want to set status to "${_prettyStatus(a.value)}"?',
                          );
                          if (!ok) return;
                        }

                        try {
                          if (a.value == 'cancelled') {
                            await _service.cancelOrder(orderId: orderId);
                          } else if (a.value == 'rejected') {
                            await _service.rejectOrder(orderId: orderId);
                          } else if (a.value == 'completed') {
  await _service.completeOrder(orderId: orderId);
} else {
  await _service.updateStatus(orderId: orderId, newStatus: a.value);
}


                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Status updated to ${_prettyStatus(a.value)}')),
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
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nextHint(String status, bool isBuyerTab, bool alreadyRated) {
    if (status == 'pending') return isBuyerTab ? 'You can cancel while pending.' : 'Tap to accept or reject.';
    if (status == 'accepted') return isBuyerTab ? 'Waiting seller to start work.' : 'Tap to start work.';
    if (status == 'in_progress') return isBuyerTab ? 'Seller is working.' : 'Tap when ready to deliver.';
    if (status == 'delivered') return isBuyerTab ? 'Tap to complete order.' : 'Waiting buyer to complete.';
    if (status == 'completed') {
      if (isBuyerTab && !alreadyRated) return 'Tap to rate seller.';
      return 'Order completed.';
    }
    if (status == 'cancelled') return 'Order cancelled.';
    if (status == 'rejected') return 'Order rejected.';
    return '';
  }

  Widget _buildOrderList({
    required List<_OrderRow> items,
    required String uid,
    required bool isBuyerTab,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(isBuyerTab ? 'No orders (as buyer) yet.' : 'No orders (as seller) yet.'),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final o = items[i];
        final isSeller = o.sellerId == uid;
        final isBuyer = o.buyerId == uid;

        // ✅ premium card row (fix overflow by using Expanded + safe sizes)
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 1.2,
            shadowColor: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showActions(
                context: context,
                orderId: o.id,
                status: o.status,
                isSeller: isSeller,
                isBuyer: isBuyer,
                alreadyRated: o.alreadyRated,
                proofImageUrl: o.proofImageUrl,

                paymentStatus: o.paymentStatus,
                paymentReceiptUrl: o.paymentReceiptUrl,
                depositAmount: o.depositAmount,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // title + price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  o.gigTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'RM ${o.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // status pill + hint
                          Row(
                            children: [
                              _StatusPill(
                                label: _prettyStatus(o.status),
                                color: _chipColor(o.status),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _nextHint(o.status, isBuyerTab, o.alreadyRated),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12.5,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          _priceBreakdown(o),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // RIGHT thumbnail
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey.shade100,
                            child: o.proofImageUrl.trim().isNotEmpty
                                ? Image.network(
                                    o.proofImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.broken_image,
                                      color: Colors.grey.shade500,
                                    ),
                                  )
                                : Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          o.proofImageUrl.trim().isNotEmpty ? 'Proof' : 'No proof',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please login first.')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'As Buyer'),
              Tab(text: 'As Seller'),
            ],
          ),
        ),
        body: StreamBuilder(
          stream: _service.streamMyOrders(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

              final all = docs.map((d) {
              final data = d.data();

              final proofUrl = (data['proofImageUrl'] ?? '').toString();
              final amount = _toDouble(data['amount']);
              final transport = _toDouble(data['transportCharge']);
              final dist = _toDouble(data['distanceKm']);
              final addr = (data['serviceAddress'] ?? '').toString();
              final total = _toDouble(data['totalAmount']);
              final computedTotal = total > 0 ? total : (amount + transport);
              final paymentStatus = (data['paymentStatus'] ?? '').toString();
              final paymentReceiptUrl = (data['paymentReceiptUrl'] ?? '').toString();
              final depositAmount = _toDouble(data['depositAmount']);

              return _OrderRow(
                id: d.id,
                gigTitle: (data['gigTitle'] ?? '').toString(),
                amount: amount,
                transportCharge: transport,
                distanceKm: dist,
                serviceAddress: addr,
                totalAmount: computedTotal,
                proofImageUrl: proofUrl,
                status: (data['status'] ?? 'pending').toString(),
                buyerId: (data['buyerId'] ?? '').toString(),
                sellerId: (data['sellerId'] ?? '').toString(),
                alreadyRated: data['rating'] != null,
                paymentStatus: paymentStatus,
                paymentReceiptUrl: paymentReceiptUrl,
                depositAmount: depositAmount,

              );
            }).toList();

            final buyerOrders = all.where((o) => o.buyerId == uid).toList();
            final sellerOrders = all.where((o) => o.sellerId == uid).toList();

            return TabBarView(
              children: [
                _buildOrderList(items: buyerOrders, uid: uid, isBuyerTab: true),
                _buildOrderList(items: sellerOrders, uid: uid, isBuyerTab: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.95),
          fontWeight: FontWeight.w800,
          fontSize: 12.2,
        ),
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final String value;
  _ActionItem(this.label, this.value);
}

class _OrderRow {

  final String paymentStatus;
  final String paymentReceiptUrl;
  final double depositAmount;

  final String id;
  final String gigTitle;

  final double amount; // service amount
  final double transportCharge;
  final double distanceKm;
  final String serviceAddress;

  final double totalAmount;
  final String proofImageUrl;

  final String status;
  final String buyerId;
  final String sellerId;
  final bool alreadyRated;

  _OrderRow({
    required this.id,
    required this.gigTitle,
    required this.amount,
    required this.transportCharge,
    required this.totalAmount,
    required this.distanceKm,
    required this.serviceAddress,
    required this.proofImageUrl,
    required this.status,
    required this.buyerId,
    required this.sellerId,
    required this.alreadyRated,

    // NEW
    required this.paymentStatus,
    required this.paymentReceiptUrl,
    required this.depositAmount,

  });
}
