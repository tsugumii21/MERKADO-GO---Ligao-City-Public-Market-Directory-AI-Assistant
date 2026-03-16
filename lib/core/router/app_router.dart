import '../../features/map/indoor_map_screen.dart';
// GoRouter configuration with role-based routing
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/get_started_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/email_verify_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/stalls/presentation/stall_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/map/presentation/report_screen.dart';
import '../../features/admin/presentation/admin_main_shell.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_map_screen.dart';
import '../../features/admin/presentation/manage_stalls_screen.dart';
import '../../features/admin/presentation/add_edit_stall_screen.dart';
import '../../features/admin/presentation/reports_screen.dart';
import 'route_names.dart';

// Import GlobalKeys for page state management
import '../widgets/main_shell.dart'
  show MainShell, mapPageKey, stallsPageKey, profilePageKey;

class AppRouter {
  static void setContainer(ProviderContainer _) {}
  
  static GoRouter router() {
    try {
      return GoRouter(
        initialLocation: RouteNames.splash,
      routes: [
        // Indoor Map Screen (user)
        GoRoute(
          path: '/indoor-map',
          builder: (context, state) => const IndoorMapScreen(),
        ),
        // Splash Screen
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        
        // Get Started Screen
        GoRoute(
          path: RouteNames.getStarted,
          builder: (context, state) => const GetStartedScreen(),
        ),
        
        // Auth Routes
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.signup,
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: RouteNames.verifyEmail,
          builder: (context, state) => const EmailVerifyScreen(),
        ),
        GoRoute(
          path: RouteNames.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        
        // User Routes with Bottom Navigation (3 tabs: Map, Stalls, Profile)
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShell(navigationShell: navigationShell);
          },
          branches: [
            // Branch 0: Map (preserve camera, markers, chatbot)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.home,
                  builder: (context, state) => MapScreen(key: mapPageKey),
                ),
              ],
            ),
            // Branch 1: Stalls (preserve filter chip, favorites)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.stalls,
                  builder: (context, state) => StallListScreen(key: stallsPageKey),
                ),
              ],
            ),
            // Branch 2: Profile
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.profile,
                  builder: (context, state) => ProfileScreen(key: profilePageKey),
                ),
              ],
            ),
          ],
        ),
        
        // Other User Routes
        GoRoute(
          path: RouteNames.editProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.reportStall,
          builder: (context, state) {
            final stallId = state.pathParameters['id'] ?? '';
            return ReportScreen(stallId: stallId);
          },
        ),
        
        // Admin Routes with Bottom Navigation (3 tabs: Dashboard, Map, Stalls)
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AdminMainShell(navigationShell: navigationShell);
          },
          branches: [
            // Branch 0: Dashboard
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.admin,
                  builder: (context, state) => const AdminDashboardScreen(),
                ),
              ],
            ),
            // Branch 1: Map (admin map with editing)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.adminMap,
                  builder: (context, state) => const AdminMapScreen(),
                ),
              ],
            ),
            // Branch 2: Stalls Management
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.adminStalls,
                  builder: (context, state) => const ManageStallsScreen(),
                ),
              ],
            ),
          ],
        ),
        
        // Admin Sub-Routes (outside bottom nav)
        GoRoute(
          path: RouteNames.adminAddStall,
          builder: (context, state) => const AddEditStallScreen(),
        ),
        GoRoute(
          path: RouteNames.adminEditStall,
          builder: (context, state) {
            final stallId = state.pathParameters['id'];
            return AddEditStallScreen(stallId: stallId);
          },
        ),
        GoRoute(
          path: '/admin/stalls/edit/:id',
          builder: (context, state) {
            final stallId = state.pathParameters['id'];
            return AddEditStallScreen(stallId: stallId);
          },
        ),
        GoRoute(
          path: RouteNames.adminReports,
          builder: (context, state) => const ReportsScreen(),
        ),
      ],
      redirect: (context, state) async {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final isLoggingIn = state.uri.toString() == RouteNames.login;
          final isSigningUp = state.uri.toString() == RouteNames.signup;
          final isOnSplash = state.uri.toString() == RouteNames.splash;
          final isVerifyingEmail = state.uri.toString() == RouteNames.verifyEmail;
          final isGetStarted = state.uri.toString() == RouteNames.getStarted;
          final isForgotPassword = state.uri.toString() == RouteNames.forgotPassword;

          // Allow splash, get started, login, signup, forgot password without redirect
          if (isOnSplash || isGetStarted || isLoggingIn || isSigningUp || isForgotPassword) {
            return null;
          }

          // Not authenticated -> get started
          if (user == null) {
            return RouteNames.login;
          }

          // Email not verified -> verify screen
          if (!user.emailVerified && !isVerifyingEmail) {
            return RouteNames.verifyEmail;
          }

          // Check user role from Firestore
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            if (userDoc.exists) {
              final role = userDoc.data()?['role'] as String?;

              // Admin role -> admin dashboard
              if (role == 'admin' && !state.uri.toString().startsWith('/admin')) {
                return RouteNames.admin;
              }

              // Regular user trying to access admin routes -> redirect to home
              if (role == 'user' && state.uri.toString().startsWith('/admin')) {
                return RouteNames.home;
              }
              
              // Non-admin trying to access admin routes -> redirect to home
              if (role != 'admin' && state.uri.toString().startsWith('/admin')) {
                return RouteNames.home;
              }
            }
          } catch (e) {
            // Error fetching role, default to home
            debugPrint('❌ Error: Failed to fetch user role: $e');
            return RouteNames.home;
          }

          return null;
        } catch (e) {
          debugPrint('❌ Failed: GoRouter redirect crashed: $e');
          return RouteNames.splash;
        }
      },
    );
    } catch (e) {
      debugPrint('❌ Failed: Failed to create GoRouter: $e');
      // Return a minimal fallback router
      return GoRouter(
        initialLocation: RouteNames.splash,
        routes: [
          GoRoute(
            path: RouteNames.splash,
            builder: (context, state) => const SplashScreen(),
          ),
        ],
      );
    }
  }
}
