import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/attachments/providers/storage_quota_provider.dart';
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
      appBar: AppBar(title: const Text('Settings'), leading: const BackButton()),
      body: ListView(
        children: [
          // ── Storage Quota (Free Tier Only) ─────────────────────────────
          _StorageQuotaSection(textTheme: t),
          const Divider(),

          // ── Appearance ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('APPEARANCE', style: t.labelSmall?.copyWith(letterSpacing: 1.2)),
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
                  onSelected: (_) => ref.read(themeModeProvider.notifier).setMode(mode),
                );
              }).toList(),
            ),
          ),
          const Divider(),

          // ── About ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('ABOUT', style: t.labelSmall?.copyWith(letterSpacing: 1.2)),
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

/// Displays storage quota and tier information (if free tier).
///
/// Shows a progress bar with usage percentage and an "Upgrade" CTA button.
/// Hides entirely for premium tier users.
class _StorageQuotaSection extends ConsumerWidget {
  const _StorageQuotaSection({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(storageQuotaProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return quota.when(
      // Loading state
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STORAGE', style: textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ),
      ),
      // Error state
      error: (error, stack) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Text(
          'Unable to load storage info',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        ),
      ),
      // Data loaded
      data: (storageQuota) {
        // Hide storage section entirely for premium tier
        if (storageQuota.tier != 'free') {
          return const SizedBox.shrink();
        }

        final usagePercent = storageQuota.usagePercent;
        final usedMb = (storageQuota.totalBytesUsed / (1024 * 1024)).toStringAsFixed(1);
        final limitMb = (storageQuota.quotaLimitBytes / (1024 * 1024)).toStringAsFixed(0);
        final attachmentCount = storageQuota.attachmentCount;
        final attachmentLimit = storageQuota.attachmentLimit;

        // Determine progress bar color based on usage
        Color getProgressColor() {
          if (usagePercent >= 95) return colorScheme.error;
          if (usagePercent >= 80) return colorScheme.tertiary; // Yellow
          return colorScheme.primary; // Green
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STORAGE', style: textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercent / 100,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation(getProgressColor()),
                ),
              ),
              const SizedBox(height: 8),
              // Usage text (space used)
              Text('$usedMb MB of $limitMb MB used', style: textTheme.bodySmall),
              const SizedBox(height: 4),
              // Usage text (attachment count)
              Text('$attachmentCount of $attachmentLimit attachments', style: textTheme.bodySmall),
              const SizedBox(height: 12),
              // Upgrade button (stub for now, no navigation)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to premium tier purchase flow
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Premium tier coming soon!'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  },
                  child: const Text('Upgrade to Premium'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
