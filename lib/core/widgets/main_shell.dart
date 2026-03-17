import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
            final currentIndex = widget.navigationShell.currentIndex;

            // Don't process if same tab tapped
            if (index == currentIndex) return;

            // Reset UI state on the page being LEFT
            _resetPage(currentIndex);

            // Update current index
            setState(() {
              _currentIndex = index;
            });

            // Navigate to the new tab
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == currentIndex,
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
