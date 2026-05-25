import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/storage_quota.dart';
import 'package:stayon/features/attachments/providers/storage_quota_provider.dart';
import 'package:stayon/features/settings/ui/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('displays storage quota section for free tier', (tester) async {
      // Mock free tier quota
      final freeQuota = StorageQuota(
        ownerUserId: 'user-1',
        tier: 'free',
        totalBytesUsed: 10485760, // 10 MB
        quotaLimitBytes: 52428800, // 50 MB
        attachmentCount: 5,
        attachmentLimit: 10,
        updatedAt: DateTime.utc(2026, 5, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageQuotaProvider.overrideWith((ref) async => freeQuota),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify storage section is visible
      expect(find.text('STORAGE'), findsWidgets);
      expect(find.text('10.0 MB of 50 MB used'), findsOneWidget);
      expect(find.text('5 of 10 attachments'), findsOneWidget);
      expect(find.text('Upgrade to Premium'), findsOneWidget);
    });

    testWidgets('hides storage quota section for premium tier', (tester) async {
      // Mock premium tier quota
      final premiumQuota = StorageQuota(
        ownerUserId: 'user-1',
        tier: 'premium',
        totalBytesUsed: 1073741824, // 1 GB
        quotaLimitBytes: 5368709120, // 5 GB
        attachmentCount: 100,
        attachmentLimit: 1000,
        updatedAt: DateTime.utc(2026, 5, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageQuotaProvider.overrideWith((ref) async => premiumQuota),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify storage section is hidden
      expect(find.text('5 of 10 attachments'), findsNothing);
      expect(find.text('Upgrade to Premium'), findsNothing);
    });

    testWidgets('progress bar color changes based on usage', (tester) async {
      // Test with 85% usage (yellow/tertiary color)
      final highUsageQuota = StorageQuota(
        ownerUserId: 'user-1',
        tier: 'free',
        totalBytesUsed: 44564480, // 42.5 MB out of 50 MB = 85%
        quotaLimitBytes: 52428800, // 50 MB
        attachmentCount: 8,
        attachmentLimit: 10,
        updatedAt: DateTime.utc(2026, 5, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageQuotaProvider.overrideWith((ref) async => highUsageQuota),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify usage percentage is shown correctly
      expect(find.text('42.5 MB of 50 MB used'), findsOneWidget);
    });

    testWidgets('upgrade button shows snackbar on tap', (tester) async {
      final freeQuota = StorageQuota(
        ownerUserId: 'user-1',
        tier: 'free',
        totalBytesUsed: 10485760, // 10 MB
        quotaLimitBytes: 52428800, // 50 MB
        attachmentCount: 5,
        attachmentLimit: 10,
        updatedAt: DateTime.utc(2026, 5, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageQuotaProvider.overrideWith((ref) async => freeQuota),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the upgrade button
      await tester.tap(find.text('Upgrade to Premium'));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.text('Premium tier coming soon!'), findsOneWidget);
    });
  });
}
