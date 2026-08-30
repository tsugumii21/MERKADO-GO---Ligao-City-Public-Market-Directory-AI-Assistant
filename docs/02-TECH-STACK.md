# Part 2 — Tech Stack & Architecture

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | Flutter 3.3+ (Dart) | Cross-platform UI framework (Android + Web) |
| **State Management** | Riverpod 2.x | Reactive state management with code generation |
| **Navigation** | GoRouter 14.x | Declarative routing with role-based redirects |
| **Backend Auth** | Firebase Auth | Email/password authentication, email verification |
| **Backend Database** | Cloud Firestore | NoSQL document database for stalls, users, reports |
| **AI Assistant** | Google Generative AI (Gemini 2.5 Flash) | Conversational chatbot for market queries |
| **Image Storage** | Cloudinary | Cloud-hosted stall photos and profile images |
| **Maps** | Google Maps Flutter | Interactive map with custom markers |
| **Location** | Geolocator | GPS device location for centering map |
| **Environment** | flutter_dotenv | API key management via `.env` file |

---

## All Dependencies (from `pubspec.yaml`)

### Production Dependencies

| Package | Version | What It Does |
|---------|---------|-------------|
| `firebase_core` | ^3.6.0 | Firebase initialization |
| `firebase_auth` | ^5.3.1 | Email/password authentication |
| `cloud_firestore` | ^5.4.4 | Firestore database operations |
| `firebase_messaging` | ^15.1.3 | Push notifications (stub — not fully implemented yet) |
| `flutter_riverpod` | ^2.6.1 | State management |
| `riverpod_annotation` | ^2.6.1 | Code generation annotations for Riverpod |
| `go_router` | ^14.6.2 | Declarative routing |
| `google_generative_ai` | ^0.4.6 | Gemini AI SDK |
| `google_maps_flutter` | ^2.9.0 | Google Maps widget |
| `geolocator` | ^11.0.0 | Device GPS location |
| `image_picker` | ^1.1.2 | Camera/gallery image selection |
| `flutter_image_compress` | ^2.3.0 | Compress images before upload |
| `cached_network_image` | ^3.4.1 | Cached image loading from URLs |
| `cloudinary_public` | ^0.23.1 | Cloudinary upload helper |
| `http` | ^1.2.2 | HTTP requests (Cloudinary REST API) |
| `permission_handler` | ^11.3.1 | Runtime permissions (location, camera) |
| `flutter_dotenv` | ^5.2.1 | Load `.env` file variables |
| `shared_preferences` | ^2.3.3 | Local key-value storage |
| `intl` | ^0.20.0 | Date/time formatting |
| `flutter_markdown` | ^0.7.3 | Render markdown (AI chat responses) |
| `google_fonts` | ^6.2.1 | Custom fonts (Poppins, Outfit, DM Sans) |
| `lottie` | ^3.1.3 | Lottie animation playback |
| `timeago` | ^3.7.0 | Human-readable time strings ("2 hours ago") |
| `uuid` | ^4.5.1 | Generate unique IDs |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

### Dev Dependencies

| Package | Version | What It Does |
|---------|---------|-------------|
| `flutter_test` | SDK | Unit/widget testing |
| `build_runner` | ^2.4.13 | Code generation runner |
| `riverpod_generator` | ^2.6.2 | Generates Riverpod providers |
| `json_serializable` | ^6.9.2 | JSON serialization code generation |
| `flutter_lints` | ^5.0.0 | Lint rules |

---

## Architecture Pattern

MerkadoGo uses a **feature-first** architecture with **Clean Architecture** layers inside each feature:

```
lib/
├── core/               ← Shared across ALL features
│   ├── constants/      ← API keys, strings, category definitions
│   ├── router/         ← App-wide routing
│   ├── services/       ← External service integrations
│   ├── theme/          ← Design system (colors, typography, spacing)
│   ├── responsive/     ← Breakpoint definitions & layout helpers
│   ├── utils/          ← Pure utility functions
│   └── widgets/        ← Shared widgets (navigation shell, loading)
│
├── features/           ← One folder per feature
│   └── [feature]/
│       ├── data/       ← Repository implementations (Firestore queries)
│       ├── domain/     ← Models & entities (pure Dart, no Flutter)
│       └── presentation/
│           ├── screens ← UI screens (StatelessWidget / ConsumerWidget)
│           ├── widgets/← Feature-specific reusable widgets
│           └── controllers ← Riverpod StateNotifier / AsyncNotifier
│
├── models/             ← Shared data models used across features
└── providers/          ← Shared Riverpod providers
```

### How Data Flows

```
UI Screen (ConsumerWidget)
    │
    ├── reads state from ──→ Riverpod Provider
    │                            │
    │                            ├── calls ──→ Repository (data/)
    │                            │                │
    │                            │                └── queries ──→ Firestore / API
    │                            │
    │                            └── calls ──→ Service (core/services/)
    │                                              │
    │                                              └── calls ──→ Gemini / Cloudinary
    │
    └── dispatches actions to ──→ Controller (StateNotifier)
                                      │
                                      └── updates ──→ Provider state
                                                        │
                                                        └── triggers ──→ UI rebuild
```

---

## State Management (Riverpod)

### What is Riverpod?

Riverpod is a reactive state management solution. Instead of passing data through widget trees, you declare **providers** that hold state, and **consumers** that watch those providers and rebuild when state changes.

### Provider Files (`lib/providers/`)

| File | What It Provides |
|------|-----------------|
| `auth_provider.dart` | Current `User` auth state from Firebase |
| `user_provider.dart` | Current user's Firestore document (`UserModel`) |
| `stall_provider.dart` | List of all stalls + filtered stall queries |
| `chat_provider.dart` | AI chat message history and streaming state |
| `favorite_provider.dart` | User's favorited stall IDs |
| `firebase_providers.dart` | `FirebaseAuth` and `FirebaseFirestore` instance providers |
| `theme_provider.dart` | Dark/light theme mode |

### How to Use a Provider in a Screen

```dart
// 1. Extend ConsumerWidget instead of StatelessWidget
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Watch a provider — screen rebuilds when value changes
    final stalls = ref.watch(stallProvider);
    
    // 3. Read a provider — get value once, no rebuild
    final user = ref.read(userProvider);
    
    // 4. Use the data in your UI
    return ListView(
      children: stalls.map((stall) => StallCard(stall: stall)).toList(),
    );
  }
}
```

### How to Use a Provider in a StatefulWidget

```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final stalls = ref.watch(stallProvider);
    // ...
  }
}
```

---

## Responsive Design System

The app supports both **mobile** and **desktop/web** layouts using a breakpoint system.

### Breakpoints (`lib/core/responsive/responsive_breakpoints.dart`)

| Breakpoint | Width | Layout |
|-----------|-------|--------|
| **Mobile** | `< 600px` | Bottom navigation bar, stacked layouts |
| **Tablet** | `600px – 899px` | Side navigation rail, split panels |
| **Desktop** | `≥ 900px` | Full sidebar navigation, centered content areas |
| **Wide** | `≥ 1440px` | Extra-wide content constraints |

### How It Works

```dart
// Check current device size in any widget
if (AppBreakpoints.isMobile(context)) {
  // Show mobile layout (bottom nav, full-width content)
} else {
  // Show desktop layout (sidebar, centered constrained content)
}
```

### Navigation Layout

| Platform | User Portal | Admin Portal |
|----------|-------------|--------------|
| **Mobile** | Bottom navigation bar (3 tabs: Map, Stalls, Profile) | Bottom navigation bar (3 tabs: Dashboard, Map, Stalls) |
| **Desktop** | Left sidebar (240px) with logo, wordmark, nav items | Left sidebar (240px) with admin branding, nav items, shortcuts |

---

*Next: [Part 3 — Design System →](./03-DESIGN-SYSTEM.md)*
