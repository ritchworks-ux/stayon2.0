import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/theme_mode_provider.dart';

/// Minimal Settings screen — Phase 2.5.
///
/// Surfaced from the avatar pop-up menu on Home. Intentionally lightweight:
/// - Dark / Light / System theme toggle
/// - App version display
///
/// More settings (notification cadence, currency, sign-out) are planned
/// for Phase 4.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.0 (build 1)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'APPEARANCE',
              style: t.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: Text(
              currentMode == ThemeMode.system
                  ? 'Following system setting'
                  : isDark
                  ? 'On'
                  : 'Off',
            ),
            value: isDark,
            onChanged: (_) {
              // Cycle: system → light → dark → system
              final next = switch (currentMode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              ref.read(themeModeProvider.notifier).setMode(next);
            },
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          // Show which mode is active for transparency
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              children: ThemeMode.values.map((mode) {
                final label = switch (mode) {
                  ThemeMode.system => 'System',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                };
                final selected = currentMode == mode;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(themeModeProvider.notifier).setMode(mode),
                );
              }).toList(),
            ),
          ),
          const Divider(),

          // ── About ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'ABOUT',
              style: t.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(_appVersion, style: t.bodyMedium),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Region'),
            trailing: Text('Philippines (PHP)', style: t.bodyMedium),
          ),
        ],
      ),
    );
  }
}
