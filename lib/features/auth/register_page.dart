import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _auth = AuthService();
  final _users = UserService();

  bool _loading = false;
  String _error = '';

  bool _isUthmEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@uthm.edu.my');
  }

  String _deriveNameFromEmail(String email) {
    final clean = email.trim();
    final idx = clean.indexOf('@');
    if (idx <= 0) return 'Student';
    // contoh: abu.naffan -> Abu naffan (simple)
    final raw = clean.substring(0, idx).replaceAll('.', ' ').replaceAll('_', ' ');
    if (raw.trim().isEmpty) return 'Student';
    return raw.trim();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text.trim();

    setState(() {
      _loading = true;
      _error = '';
    });

    // ✅ UTHM-only guard
    if (!_isUthmEmail(email)) {
      setState(() {
        _loading = false;
        _error = 'Please use your UTHM email (example: name@uthm.edu.my).';
      });
      return;
    }

    // ✅ password guard
    if (pass.length < 6) {
      setState(() {
        _loading = false;
        _error = 'Password must be at least 6 characters.';
      });
      return;
    }

    try {
      await _auth.register(email: email, password: pass);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final name = _deriveNameFromEmail(user.email ?? email);

        await _users.createUserProfile(
          uid: user.uid,
          name: name, // ✅ FIX: required param
          email: user.email ?? email,
        );
      }

      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '${e.code}: ${e.message ?? ''}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'UTHM Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password (min 6 chars)'),
            ),
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
                    : const Text('Create Account'),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : () => context.go('/login'),
              child: const Text("Back to login"),
            ),
          ],
        ),
      ),
    );
  }
}
