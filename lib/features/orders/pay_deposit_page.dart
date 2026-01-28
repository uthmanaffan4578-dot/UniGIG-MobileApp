import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../orders/pay_deposit_page.dart';
import '../../services/order_service.dart';

class PayDepositPage extends StatefulWidget {
  final String orderId;
  final String gigTitle;
  final double depositAmount;
  final String paymentRef;
  final String sellerQrUrl;

  const PayDepositPage({
    super.key,
    required this.orderId,
    required this.gigTitle,
    required this.depositAmount,
    required this.paymentRef,
    required this.sellerQrUrl,
  });

  @override
  State<PayDepositPage> createState() => _PayDepositPageState();
}

class _PayDepositPageState extends State<PayDepositPage> {
  final _orders = OrderService();
  bool _uploading = false;

  Future<void> _pickAndUploadReceipt() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    setState(() => _uploading = true);
    try {
      await _orders.uploadPaymentReceipt(orderId: widget.orderId, file: x);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt uploaded. Pending verification.')),
      );
      Navigator.pop(context); // balik ke detail / orders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Deposit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gigTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Deposit: RM ${widget.depositAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            SelectableText('Reference: ${widget.paymentRef}'),
            const SizedBox(height: 16),

            if (widget.sellerQrUrl.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Text(
                  'Seller QR not available. Ask seller to upload QR in gig.',
                ),
              )
            else
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.sellerQrUrl,
                    height: 240,
                    width: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Text('Failed to load QR image'),
                  ),
                ),
              ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _pickAndUploadReceipt,
                child: Text(_uploading ? 'Uploading...' : 'Upload Receipt'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
