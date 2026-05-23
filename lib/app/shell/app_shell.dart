import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../../features/items/controllers/item_providers.dart';
import '../../features/items/ui/item_form_sheet.dart';
import '../../features/items/utils/date_buckets.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  Future<void> _openAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ItemFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive overdue count from the live items list.
    // Falls back to 0 while loading or on error — the badge simply won't
    // appear until data is available, which is the right UX.
    final overdueCount = ref.watch(itemsProvider).whenOrNull(
          data: (items) => items
              .where((i) => bucketFor(i.targetDate) == DateBucket.overdue)
              .length,
        ) ??
        0;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Calendar',
      ),
      NavigationDestination(
        icon: Badge(
          label: overdueCount > 0 ? Text('$overdueCount') : null,
          child: const Icon(Icons.notifications_outlined),
        ),
        selectedIcon: Badge(
          label: overdueCount > 0 ? Text('$overdueCount') : null,
          child: const Icon(Icons.notifications),
        ),
        label: 'Alerts',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: 'Family',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        onPressed: () => _openAddSheet(context),
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
