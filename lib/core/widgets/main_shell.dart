import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../responsive/responsive_breakpoints.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/stalls/presentation/stall_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

// GlobalKeys for accessing each page's State (for resetUI)
final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();
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
  ConsumerState<MainShell> createState() => MainShellState();
}

class MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex != widget.navigationShell.currentIndex) {
      _currentIndex = widget.navigationShell.currentIndex;
    }
  }

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

  void _onTabSelected(int index) {
    final currentIndex = widget.navigationShell.currentIndex;
    if (index == currentIndex) return;

    _resetPage(currentIndex);

    setState(() {
      _currentIndex = index;
    });

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
    );
  }

  void goToTab(int index, {bool resetCurrentPage = true}) {
    if (!mounted) return;

    final currentIndex = widget.navigationShell.currentIndex;
    if (index == currentIndex) return;

    if (resetCurrentPage) {
      _resetPage(currentIndex);
    }

    setState(() {
      _currentIndex = index;
    });

    widget.navigationShell.goBranch(index, initialLocation: false);
  }

  void openFavoriteStalls() {
    if (!mounted) return;

    final applyFavoritesView = () {
      if (!mounted) return;
      stallsPageKey.currentState?.showFavoritesView();
    };

    if (widget.navigationShell.currentIndex != 1) {
      goToTab(1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyFavoritesView();
        Future<void>.delayed(const Duration(milliseconds: 80), applyFavoritesView);
      });
      return;
    }

    applyFavoritesView();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isWideOrTablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

    if (isWideOrTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _onTabSelected,
              extended: isDesktop,
              minWidth: 72,
              minExtendedWidth: 220,
              backgroundColor: colorScheme.surface,
              indicatorColor: colorScheme.primaryContainer,
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
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'MERKADO GO',
                            style: TextStyle(
                              fontSize: 16,
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
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined, size: 24),
                  selectedIcon: Icon(Icons.map_rounded, size: 26),
                  label: Text('Market Map'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined, size: 24),
                  selectedIcon: Icon(Icons.storefront_rounded, size: 26),
                  label: Text('Stalls'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded, size: 24),
                  selectedIcon: Icon(Icons.person_rounded, size: 26),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

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
          onDestinationSelected: _onTabSelected,
          height: 70,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 24),
              selectedIcon: Icon(Icons.map_rounded, size: 26),
              label: 'Market Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, size: 24),
              selectedIcon: Icon(Icons.storefront_rounded, size: 26),
              label: 'Stalls',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              selectedIcon: Icon(Icons.person_rounded, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

