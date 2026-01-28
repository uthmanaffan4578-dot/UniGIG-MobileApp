import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'theme/app_theme.dart';
import 'core/router/app_router.dart' as router;
import 'theme/theme_mode_provider.dart'; // 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: UniGIGApp()));

  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e, st) {
    debugPrint('❌ Firebase init failed: $e');
    debugPrint('$st');
  }

  runApp(const ProviderScope(child: UniGIGApp()));
}

class UniGIGApp extends ConsumerWidget {
  const UniGIGApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode, // ✅ dynamic
      routerConfig: router.appRouter,
    );
  }
}
