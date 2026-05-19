import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/auth_providers.dart';
import '../../items/controllers/item_providers.dart';
import '../../items/ui/widgets/empty_home_state.dart';
import '../../items/ui/widgets/item_card_section.dart';
import '../../items/utils/date_buckets.dart';

/// Home dashboard.
///
/// Header: greeting + sign-out icon.
/// Body: live `itemsProvider` data, grouped into Overdue / This week /
/// This month / Later sections. Loading/empty/error all handled.
/// Pull-to-refresh re-fetches via `ref.refresh(itemsProvider.future)`.
///
/// Tap on an [ItemCard] currently shows a placeholder snackbar; Task 15
/// wires `/item/:id` routing and replaces this stub.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final items = ref.watch(itemsProvider);
    final greeting = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : user?.email.split('@').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Returns the next-fetch Future; RefreshIndicator awaits it
            // before hiding its spinner. Use unawaited-style discard so
            // the analyzer doesn't flag `refresh`'s return value.
            final _ = await ref.refresh(itemsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _GreetingHeader(greeting: greeting, ref: ref),
              ),
              items.when(
                skipLoadingOnRefresh: false,
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    onRetry: () => ref.invalidate(itemsProvider),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyHomeState(),
                    );
                  }
                  final buckets = bucketize(list);
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        for (final bucket in DateBucket.values)
                          ItemCardSection(
                            bucket: bucket,
                            items: buckets[bucket] ?? const [],
                            onTapItem: (item) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Tapped "${item.name}". '
                                    'Item Detail arrives in Phase 2 Task 15.',
                                  ),
                                ),
                              );
                            },
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting, required this.ref});
  final String greeting;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good morning,', style: t.bodyLarge),
                Text(greeting, style: t.displayMedium),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.ink),
          const SizedBox(height: 16),
          Text(
            "Couldn't load your items",
            style: t.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
