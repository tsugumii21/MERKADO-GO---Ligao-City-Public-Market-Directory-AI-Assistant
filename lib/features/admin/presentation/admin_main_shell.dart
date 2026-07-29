import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive/responsive_breakpoints.dart';

/// Admin Main Shell with responsive navigation (Dashboard, Map, Stalls)
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
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isWideOrTablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

    if (isWideOrTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              extended: isDesktop,
              minWidth: 72,
              minExtendedWidth: 220,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF1B5E20).withOpacity(0.15),
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'ADMIN PORTAL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B5E20),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1B5E20)),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map, color: Color(0xFF1B5E20)),
                  label: Text('Map'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.store_outlined),
                  selectedIcon: Icon(Icons.store, color: Color(0xFF1B5E20)),
                  label: Text('Stalls'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1B5E20).withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1B5E20)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Color(0xFF1B5E20)),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store, color: Color(0xFF1B5E20)),
            label: 'Stalls',
          ),
        ],
      ),
    );
  }
}

