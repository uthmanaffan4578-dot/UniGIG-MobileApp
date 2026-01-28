import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';

import '../../services/gig_service.dart';

class CreateGigPage extends StatefulWidget {
  const CreateGigPage({super.key});

  @override
  State<CreateGigPage> createState() => _CreateGigPageState();
}

class _CreateGigPageState extends State<CreateGigPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _ratePerKm = TextEditingController(text: '2');
  final _deposit = TextEditingController(text: '0');
  File? _qrFile;
  String _qrName = '';

  String _category = 'General';
  bool _loading = false;
  String _error = '';

  // ✅ new
  bool _requiresLocation = false;
  GeoPoint? _sellerLocation;
  String _sellerAddress = '';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _ratePerKm.dispose();
    _deposit.dispose();
    super.dispose();
    
  }

  Future<void> _pickSellerLocation() async {
    try {
      // permission flow
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final gp = GeoPoint(pos.latitude, pos.longitude);

      String addr = '';
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
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
      } catch (_) {
        // ok if reverse geo fails
      }

      if (!mounted) return;
      setState(() {
        _sellerLocation = gp;
        _sellerAddress = addr;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller location saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _pickQr() async {
  try {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return;

    setState(() {
      _qrFile = File(x.path);
      _qrName = x.name;
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to pick QR: $e')),
    );
  }
}


  Future<void> _submit() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    
    final title = _title.text.trim();
    final desc = _desc.text.trim();
    final price = double.tryParse(_price.text.trim());
    final rate = double.tryParse(_ratePerKm.text.trim()) ?? 2.0;

    if (title.isEmpty || desc.isEmpty || price == null) {
      setState(() {
        _loading = false;
        _error = 'Please fill all fields correctly.';
      });
      return;
    }

    // ✅ if requiresLocation, seller MUST set location
    if (_requiresLocation && _sellerLocation == null) {
      setState(() {
        _loading = false;
        _error = 'Please set your seller location (required for this gig).';
      });
      return;
    }

    final depositAmount = double.tryParse(_deposit.text.trim()) ?? 0.0;

    if (depositAmount > 0 && _qrFile == null) {
  setState(() {
    _loading = false;
    _error = 'Deposit set but QR not uploaded. Please upload seller QR.';
  });
  return;
}

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be logged in.');

      final service = GigService();
      final storage = StorageService();
      
      final gigId = await service.createGig(
        title: title,
        description: desc,
        category: _category,
        price: price,
        sellerId: user.uid,

        requiresLocation: _requiresLocation,
        sellerLocation: _sellerLocation,
        sellerAddress: _sellerAddress,
        ratePerKm: rate,

        depositAmount: depositAmount,
        qrImageUrl: '',
      );

      // 2) upload QR if exists, then update gig doc
if (_qrFile != null) {
  final qrUrl = await storage.uploadSellerQr(gigId: gigId, file: _qrFile!);

  await FirebaseFirestore.instance.collection('gigs').doc(gigId).update({
    'qrImageUrl': qrUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

      if (!mounted) return;
      context.pop();
 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gig published!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Gig'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _desc,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price (RM)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

TextField(
  controller: _deposit,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: const InputDecoration(
    labelText: 'Deposit Amount (RM)',
    hintText: 'e.g. 10.00 (optional)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

OutlinedButton.icon(
  onPressed: _loading ? null : _pickQr,
  icon: const Icon(Icons.qr_code_2),
  label: Text(_qrFile == null ? 'Upload Seller QR (DuitNow)' : 'QR Selected: $_qrName'),
),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(value: 'Design', child: Text('Design')),
                  DropdownMenuItem(value: 'Tutoring', child: Text('Tutoring')),
                  DropdownMenuItem(value: 'Coding', child: Text('Coding')),
                  DropdownMenuItem(
                      value: 'Video Editing', child: Text('Video Editing')),
                  DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                  DropdownMenuItem(
                      value: 'Electrical', child: Text('Electrical')),
                ],
                onChanged:
                    _loading ? null : (v) => setState(() => _category = v ?? 'General'),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requires on-site location?'),
                subtitle: const Text('Cleaning / electrical / fixing usually need location.'),
                value: _requiresLocation,
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _requiresLocation = v),
              ),

              if (_requiresLocation) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickSellerLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _sellerLocation == null
                        ? 'Set Seller Location (Use Current Location)'
                        : 'Update Seller Location',
                  ),
                ),
                const SizedBox(height: 6),
                if (_sellerAddress.isNotEmpty)
                  Text(
                    'Seller address: $_sellerAddress',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                const SizedBox(height: 12),

                TextField(
                  controller: _ratePerKm,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Transport Rate (RM per km)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),

              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
