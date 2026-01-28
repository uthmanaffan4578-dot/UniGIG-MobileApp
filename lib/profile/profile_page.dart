import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../services/user_service.dart';

// ✅ theme toggle provider
import '../theme/theme_mode_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _svc = UserService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _name = TextEditingController();
  final _faculty = TextEditingController();
  final _phone = TextEditingController();

  bool _saving = false;
  bool _hydrated = false; // prevent overwrite while typing

  @override
  void dispose() {
    _name.dispose();
    _faculty.dispose();
    _phone.dispose();
    super.dispose();
  }

  // 📸 pick + upload profile photo
  Future<void> _pickAndUploadPhoto(String uid) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final url = await _storage.uploadProfilePhoto(file);
      await _svc.updatePhotoUrl(uid: uid, photoUrl: url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  // 💾 save profile
  Future<void> _save(String uid) async {
    setState(() => _saving = true);
    try {
      await _svc.updateMyProfile(
        uid: uid,
        name: _name.text.trim(),
        faculty: _faculty.text.trim(),
        phone: _phone.text.trim(),
        role: 'both', // semua user boleh create gig
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  IconData _modeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first.')),
      );
    }

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _svc.watchMyProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load profile.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final email = (data['email'] ?? user.email ?? '').toString();
          final photoUrl = (data['photoUrl'] ?? '').toString();

          // hydrate ONCE
          if (!_hydrated) {
            _name.text = (data['name'] ?? '').toString();
            _faculty.text = (data['faculty'] ?? '').toString();
            _phone.text = (data['phone'] ?? '').toString();
            _hydrated = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== HEADER CARD =====
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _pickAndUploadPhoto(user.uid),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty ? const Icon(Icons.person, size: 32) : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name.text.isEmpty ? 'Your Name' : _name.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      _faculty.text.trim().isEmpty ? 'Faculty: -' : 'Faculty: ${_faculty.text.trim()}',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _phone.text.trim().isEmpty ? 'Phone: -' : 'Phone: ${_phone.text.trim()}',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== PROFILE FORM =====
                _sectionTitle('Profile Information'),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          decoration: _fieldDeco('Name', icon: Icons.badge),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _faculty,
                          decoration: _fieldDeco('Faculty', hint: 'e.g. FSKTM', icon: Icons.school),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDeco('Phone', icon: Icons.phone),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _save(user.uid),
                            icon: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save Profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== INTERFACE THEME =====
                _sectionTitle('Interface Theme'),
                Card(
                  elevation: 0,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(_modeIcon(themeMode)),
                        title: const Text('Theme Mode'),
                        subtitle: Text(_modeLabel(themeMode)),
                        trailing: DropdownButton<ThemeMode>(
                          value: themeMode,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                          ],
                          onChanged: (m) {
                            if (m == null) return;
                            final notifier = ref.read(themeModeProvider.notifier);
                            if (m == ThemeMode.system) notifier.setSystem();
                            if (m == ThemeMode.light) notifier.setLight();
                            if (m == ThemeMode.dark) notifier.setDark();
                          },
                        ),
                      ),
                      
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ===== FOOTER =====
                
              ],
            ),
          );
        },
      ),
    );
  }
}
