import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
