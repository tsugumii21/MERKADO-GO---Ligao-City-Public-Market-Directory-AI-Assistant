import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
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
              minWidth: 76,
              minExtendedWidth: 230,
              backgroundColor: AppColors.navSurface,
              indicatorColor: AppColors.primary,
              unselectedIconTheme: const IconThemeData(color: Colors.white60, size: 22),
              selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
              unselectedLabelTextStyle: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              selectedLabelTextStyle: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'MerkadoGo',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                'Ligao Public Market',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: Text('Market Map'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: Text('Stalls'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF2A362A)),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTabSelected,
          height: 60,
          elevation: 0,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.map_rounded, size: 26, color: AppColors.primary),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.storefront_rounded, size: 26, color: AppColors.primary),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.person_rounded, size: 26, color: AppColors.primary),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}

