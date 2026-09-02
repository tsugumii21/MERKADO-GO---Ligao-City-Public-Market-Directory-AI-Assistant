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

    void applyFavoritesView() {
      if (!mounted) return;
      stallsPageKey.currentState?.showFavoritesView();
    }

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
        backgroundColor: AppColors.canvas,
        body: Row(
          children: [
            _buildDesktopSidebar(context, isDesktop),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTabSelected,
          height: 56,
          elevation: 0,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.map_rounded, size: 24, color: AppColors.primary),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.storefront_rounded, size: 24, color: AppColors.primary),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24, color: AppColors.inkMuted),
              selectedIcon: Icon(Icons.person_rounded, size: 24, color: AppColors.primary),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, bool isDesktop) {
    final sidebarWidth = isDesktop ? 240.0 : 76.0;
    final currentIndex = widget.navigationShell.currentIndex;

    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Brand Header ──
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border,
                  width: 1.0,
                ),
              ),
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/icons/MerkadoGo_Transparent Logo.png',
                          cacheWidth: 120,
                          cacheHeight: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Merkado',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Go',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Ligao Public Market',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.inkMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Image.asset(
                        'assets/icons/MerkadoGo_Transparent Logo.png',
                        cacheWidth: 100,
                        cacheHeight: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),

          // ── Navigation Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                if (isDesktop) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'EXPLORE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.inkSubtle,
                      ),
                    ),
                  ),
                ],
                _buildSidebarItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map_rounded,
                  label: 'Market Map',
                  isSelected: currentIndex == 0,
                  isDesktop: isDesktop,
                  onTap: () => _onTabSelected(0),
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  label: 'Stalls',
                  isSelected: currentIndex == 1,
                  isDesktop: isDesktop,
                  onTap: () => _onTabSelected(1),
                ),

                if (isDesktop) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'SHORTCUTS',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.inkSubtle,
                      ),
                    ),
                  ),
                  _buildSidebarItem(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    label: 'Favorites',
                    isSelected: false,
                    isDesktop: isDesktop,
                    onTap: openFavoriteStalls,
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom Footer / Profile Card ──
          Container(
            padding: EdgeInsets.all(isDesktop ? 12 : 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: 1.0,
                ),
              ),
            ),
            child: isDesktop
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onTabSelected(2),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: currentIndex == 2
                              ? AppColors.surface
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentIndex == 2
                                ? AppColors.primary
                                : AppColors.border,
                            width: currentIndex == 2 ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: currentIndex == 2
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              child: Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: currentIndex == 2
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'My Account',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: currentIndex == 2
                                          ? AppColors.primary
                                          : AppColors.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'View profile',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: currentIndex == 2
                                  ? AppColors.primary
                                  : AppColors.inkSubtle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: IconButton(
                      onPressed: () => _onTabSelected(2),
                      icon: Icon(
                        currentIndex == 2
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        color: currentIndex == 2
                            ? AppColors.primary
                            : AppColors.inkMuted,
                        size: 22,
                      ),
                      tooltip: 'Profile',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.surface.withValues(alpha: 0.8),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 0),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: AppColors.border,
                    width: 1,
                  )
                : null,
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        size: 18,
                        color: isSelected ? AppColors.primary : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      size: 20,
                      color: isSelected ? AppColors.primary : AppColors.inkMuted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

