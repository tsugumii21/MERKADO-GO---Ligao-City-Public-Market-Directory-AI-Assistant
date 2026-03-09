import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/stalls/presentation/stall_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

// GlobalKeys for accessing each page's State (for resetUI)
final GlobalKey<MapScreenState> mapPageKey = GlobalKey<MapScreenState>();
final GlobalKey<StallListScreenState> stallsPageKey = GlobalKey<StallListScreenState>();
final GlobalKey<ProfileScreenState> profilePageKey = GlobalKey<ProfileScreenState>();

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  void _resetPage(int pageIndex) {
    if (!mounted) return;
    
    switch (pageIndex) {
      case 0: // Map page
        mapPageKey.currentState?.resetUI();
        break;
      case 1: // Stalls page
        stallsPageKey.currentState?.resetUI();
        break;
      case 2: // Profile page
        profilePageKey.currentState?.resetUI();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            // Don't process if same tab tapped
            if (index == _currentIndex) return;
            
            // Reset UI state on the page being LEFT
            _resetPage(_currentIndex);
            
            // Update current index
            setState(() {
              _currentIndex = index;
            });
            
            // Navigate to the new tab
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          height: 70,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.map_outlined,
                size: 24,
              ),
              selectedIcon: Icon(
                Icons.map_rounded,
                size: 26,
              ),
              label: 'Market Map',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.storefront_outlined,
                size: 24,
              ),
              selectedIcon: Icon(
                Icons.storefront_rounded,
                size: 26,
              ),
              label: 'Stalls',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline_rounded,
                size: 24,
              ),
              selectedIcon: Icon(
                Icons.person_rounded,
                size: 26,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
