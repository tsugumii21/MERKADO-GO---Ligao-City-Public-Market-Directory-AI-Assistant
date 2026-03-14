import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin Main Shell with bottom navigation (Dashboard, Map, Stalls)
class AdminMainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminMainShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1B5E20).withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF1B5E20)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map, color: Color(0xFF1B5E20)),
            label: 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.store_outlined),
            selectedIcon: const Icon(Icons.store, color: Color(0xFF1B5E20)),
            label: 'Stalls',
          ),
        ],
      ),
    );
  }
}
