import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// App entry point: initialises Firebase once, then starts the app
/// inside a Riverpod [ProviderScope].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized');
  } catch (e, st) {
    debugPrint('Firebase init failed: $e');
    debugPrint('$st');
  }

  runApp(const ProviderScope(child: UniGIGApp()));
}
