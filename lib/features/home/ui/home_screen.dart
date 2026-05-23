import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../items/controllers/item_providers.dart';
import '../../items/ui/widgets/empty_home_state.dart';
import '../../items/ui/widgets/item_card_section.dart';
import '../../items/utils/date_buckets.dart';
import 'widgets/home_header.dart';
import 'widgets/stat_tiles.dart';
import 'widgets/this_week_hero_card.dart';

/// Home dashboard.
///
/// Header: avatar (sign-out) + time-aware greeting + bell → Alerts.
/// Body: live `itemsProvider` data. When there are items, a "This week"
/// hero card and two stat tiles (Due soon / Upcoming) sit above the
/// Overdue / This week / This month / Later sections. Loading, empty,
/// and error states are all handled. Pull-to-refresh re-fetches via
/// `ref.refresh(itemsProvider.future)`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.now});

  /// Injected in tests for a deterministic clock; defaults to the wall
  /// clock in production. Drives the greeting, hero, tiles, and buckets.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    final clock = now ?? DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Returns the next-fetch Future; RefreshIndicator awaits it
            // before hiding its spinner. Discard the value into `_` so
            // the analyzer doesn't flag `refresh`'s return.
            final _ = await ref.refresh(itemsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: HomeHeader(now: clock)),
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
                  final buckets = bucketize(list, now: clock);
                  final overdue = buckets[DateBucket.overdue]!.length;
                  final thisWeek = buckets[DateBucket.thisWeek]!.length;
                  final thisMonth = buckets[DateBucket.thisMonth]!.length;
                  final later = buckets[DateBucket.later]!.length;
                  final dueSoon = overdue + thisWeek;
                  final upcoming = thisMonth + later;

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        ThisWeekHeroCard(
                          dueSoon: dueSoon,
                          overdue: overdue,
                          onTap: () => context.go('/alerts'),
                        ),
                        const SizedBox(height: 12),
                        StatTiles(dueSoon: dueSoon, upcoming: upcoming),
                        for (final bucket in DateBucket.values)
                          ItemCardSection(
                            bucket: bucket,
                            items: buckets[bucket] ?? const [],
                            now: clock,
                            onTapItem: (item) =>
                                context.push('/item/${item.id}'),
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
