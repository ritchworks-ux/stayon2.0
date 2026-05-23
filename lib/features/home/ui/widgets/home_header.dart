import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../auth/controllers/auth_providers.dart';
import '../../../items/controllers/item_providers.dart';
import '../../../items/utils/date_buckets.dart';
import '../../utils/greeting.dart';

/// Home dashboard header: account avatar (with sign-out), a time-aware
/// greeting + the user's name, and a bell that opens the Alerts tab.
///
/// The bell shows an unread dot whenever the user has any overdue or
/// this-week items, so urgency is visible without scrolling. The avatar
/// hosts sign-out (and a placeholder Settings entry) so the old bare
/// logout icon no longer sits exposed on the home screen.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.now});

  /// Clock used for the greeting and the bell's urgency dot. Injected in
  /// tests; production passes `DateTime.now()`.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email.split('@').first ?? 'there';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final loaded = ref.watch(itemsProvider).valueOrNull;
    final hasUrgent =
        loaded != null &&
        loaded.any((item) {
          final bucket = bucketFor(item.targetDate, now: now);
          return bucket == DateBucket.overdue || bucket == DateBucket.thisWeek;
        });

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _Avatar(
            initial: initial,
            onSignOut: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            onSettings: () => context.go('/settings'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greetingLine(now), style: t.bodyLarge),
                Text(
                  name,
                  style: t.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _BellButton(
            hasUnread: hasUrgent,
            onPressed: () => context.go('/alerts'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.onSignOut,
    required this.onSettings,
  });

  final String initial;
  final VoidCallback onSignOut;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'settings') onSettings();
        if (value == 'signout') onSignOut();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.forest,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'NunitoSans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.hasUnread, required this.onPressed});

  final bool hasUnread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Alerts',
          onPressed: onPressed,
        ),
        if (hasUnread)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
