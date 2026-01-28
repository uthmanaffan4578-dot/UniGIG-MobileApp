import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_mode_provider.dart';

class ThemeToggleTile extends ConsumerWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    IconData icon;
    String label;

    switch (mode) {
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        label = 'Dark Mode';
        break;
      case ThemeMode.light:
        icon = Icons.light_mode;
        label = 'Light Mode';
        break;
      default:
        icon = Icons.settings_suggest;
        label = 'System Default';
    }

    return Card(
      child: Column(
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: mode,
            title: const Text('System Default'),
            onChanged: (_) => notifier.setSystem(),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: mode,
            title: const Text('Light Mode'),
            onChanged: (_) => notifier.setLight(),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: mode,
            title: const Text('Dark Mode'),
            onChanged: (_) => notifier.setDark(),
          ),
        ],
      ),
    );
  }
}
