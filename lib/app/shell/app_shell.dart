import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../../features/items/ui/item_form_sheet.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Calendar',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outlined),
      selectedIcon: Icon(Icons.people),
      label: 'Family',
    ),
  ];

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: _destinations,
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
