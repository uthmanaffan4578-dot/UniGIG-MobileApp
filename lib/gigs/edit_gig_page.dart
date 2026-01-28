import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/gig_service.dart';

class EditGigPage extends StatefulWidget {
  final String gigId;
  const EditGigPage({super.key, required this.gigId});

  @override
  State<EditGigPage> createState() => _EditGigPageState();
}

class _EditGigPageState extends State<EditGigPage> {
  final _service = GigService();

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();

  String _category = 'General';
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  final _categories = const [
    'General',
    'Design',
    'Tutoring',
    'Coding',
    'Video Editing',
    'Writing',
    'Cleaning',
    'Electrical',
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final snap = await _service.getGig(widget.gigId);
      final data = snap.data() ?? {};

      _title.text = (data['title'] ?? '').toString();
      _desc.text = (data['description'] ?? '').toString();

      final rawPrice = data['price'];
      final price = rawPrice is int
          ? rawPrice.toDouble()
          : (rawPrice is double ? rawPrice : 0.0);
      _price.text = price.toStringAsFixed(2);

      final cat = (data['category'] ?? 'General').toString();
      _category = _categories.contains(cat) ? cat : 'General';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Please fill all fields correctly.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      await _service.updateGig(
        gigId: widget.gigId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        price: price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gig updated')),
        );
        context.pop(); // balik ke page sebelum (GigDetail atau MyGigs)
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Gig')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (RM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'General'),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
