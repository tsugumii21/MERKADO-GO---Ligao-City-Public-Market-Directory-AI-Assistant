# Part 5 — Routing & Navigation

## Overview

MerkadoGo uses **GoRouter** for declarative, URL-based routing with **role-based access control**. The router checks Firebase Auth state and the user's Firestore `role` field to determine which screens they can access.

**File**: `lib/core/router/app_router.dart`
**Route Names**: `lib/core/router/route_names.dart`

---

## All Routes

### Public Routes (No Auth Required)

| Route Path | Screen | Description |
|-----------|--------|-------------|
| `/splash` | `SplashScreen` | Animated logo + session check |
| `/get-started` | `GetStartedScreen` | Landing page with Sign In / Create Account |
| `/login` | `LoginScreen` | Email or username sign-in |
| `/signup` | `SignupScreen` | Create account with username |
| `/register` | `SignupScreen` | Alias for `/signup` |
| `/forgot-password` | `ForgotPasswordScreen` | Send password reset email |
| `/verify-email` | `EmailVerifyScreen` | Wait for email verification |

### User Portal Routes (Auth Required, `role: "user"`)

These use a `StatefulShellRoute.indexedStack` — meaning they share a **persistent bottom navigation bar** and preserve state when switching tabs.

| Route Path | Tab Index | Screen | Description |
|-----------|-----------|--------|-------------|
| `/home` | 0 (Map) | `MapScreen` | Interactive Google Map + AI chatbot |
| `/stalls` | 1 (Stalls) | `StallListScreen` | Searchable stall directory |
| `/profile` | 2 (Profile) | `ProfileScreen` | User profile, favorites, sign out |

Additional user routes (outside the tab bar):

| Route Path | Screen | Description |
|-----------|--------|-------------|
| `/edit-profile` | `EditProfileScreen` | Edit name, username, photo |
| `/report/:id` | `ReportScreen` | Submit a report for stall `:id` |
| `/indoor-map` | `IndoorMapScreen` | 2D indoor stall layout |

### Admin Portal Routes (Auth Required, `role: "admin"`)

Also uses a `StatefulShellRoute.indexedStack` with its own navigation shell.

| Route Path | Tab Index | Screen | Description |
|-----------|-----------|--------|-------------|
| `/admin` | 0 (Dashboard) | `AdminDashboardScreen` | Stats overview + quick actions |
| `/admin/map` | 1 (Map) | `AdminMapScreen` | Interactive map with stall placement |
| `/admin/stalls` | 2 (Stalls) | `ManageStallsScreen` | Search, filter, edit, delete stalls |

Additional admin routes (outside the tab bar):

| Route Path | Screen | Description |
|-----------|--------|-------------|
| `/admin/stalls/add` | `AddEditStallScreen` | Create a new stall |
| `/admin/stalls/:id/edit` | `AddEditStallScreen` | Edit existing stall (receives `stallId`) |
| `/admin/stalls/edit/:id` | `AddEditStallScreen` | Alternative edit path |
| `/admin/reports` | `ReportsScreen` | View and manage user reports |

---

## Route Names (Constants)

All route paths are defined as constants in `lib/core/router/route_names.dart` so you never hardcode path strings:

```dart
class RouteNames {
  static const String splash = '/splash';
  static const String getStarted = '/get-started';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String stalls = '/stalls';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String reportStall = '/report/:id';
  static const String admin = '/admin';
  static const String adminMap = '/admin/map';
  static const String adminStalls = '/admin/stalls';
  static const String adminAddStall = '/admin/stalls/add';
  static const String adminEditStall = '/admin/stalls/:id/edit';
  static const String adminReports = '/admin/reports';
}
```

### How to Navigate

```dart
import 'package:go_router/go_router.dart';
import 'package:merkado_go/core/router/route_names.dart';

// Push to a new screen
context.push(RouteNames.adminAddStall);

// Navigate to a screen (replaces current)
context.go(RouteNames.home);

// Navigate with a path parameter
context.push('/admin/stalls/${stall.stallId}/edit');

// Go back
context.pop();
```

---

## Role-Based Redirect Logic

The router has a `redirect` function that runs on **every navigation**. Here's the decision flow:

```
Every Navigation →
  │
  ├─ Is it splash/get-started/login/signup/forgot-password?
  │   └─ YES → Allow (no redirect)
  │
  ├─ User not logged in?
  │   └─ YES → Redirect to /login
  │
  ├─ Email not verified?
  │   └─ YES → Redirect to /verify-email
  │
  ├─ User role = "admin" AND NOT on /admin/* route?
  │   └─ YES → Redirect to /admin (admin dashboard)
  │
  ├─ User role = "user" AND trying to access /admin/*?
  │   └─ YES → Redirect to /home (block admin access)
  │
  └─ Otherwise → Allow (no redirect)
```

**Important**: The redirect function is **async** because it reads the user's role from Firestore on every navigation.

---

## Navigation Shells

### User Navigation Shell (`MainShell`)

**File**: `lib/core/widgets/main_shell.dart`

| Platform | Layout |
|----------|--------|
| **Mobile** (`< 600px`) | Bottom navigation bar with 3 icon tabs |
| **Desktop** (`≥ 600px`) | Left sidebar (240px) with logo, wordmark, navigation items |

**Tabs**:
1. 🗺️ Map (`/home`)
2. 🏪 Stalls (`/stalls`)
3. 👤 Profile (`/profile`)

### Admin Navigation Shell (`AdminMainShell`)

**File**: `lib/features/admin/presentation/admin_main_shell.dart`

| Platform | Layout |
|----------|--------|
| **Mobile** (`< 600px`) | Bottom navigation bar with 3 icon tabs |
| **Desktop** (`≥ 600px`) | Left sidebar (240px) with admin branding, nav items, shortcuts, sign out |

**Tabs**:
1. 📊 Dashboard (`/admin`)
2. 🗺️ Map (`/admin/map`)
3. 🏪 Stalls (`/admin/stalls`)

**Sidebar Shortcuts** (desktop only):
- ➕ Add Stall → `/admin/stalls/add`
- 📋 Reports → `/admin/reports`
- 🚪 Sign Out (bottom-pinned)

---

## `StatefulShellRoute` Explained

GoRouter's `StatefulShellRoute.indexedStack` preserves the state of each tab when switching between them. This means:

- The **Map** tab keeps its camera position, loaded markers, and chat history when you switch to Stalls and back
- The **Stalls** tab keeps its scroll position, active filters, and search query
- The **Profile** tab keeps loaded user data

Each tab is a `StatefulShellBranch` with its own independent navigation stack.

---

*Next: [Part 6 — Feature: Authentication Flow →](./06-AUTH-FLOW.md)*
