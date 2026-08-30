# Part 1 — Project Overview & Setup

## What is MerkadoGo?

MerkadoGo is a **directory and interactive navigation helper** for the **Ligao City Public Market** in Albay, Philippines. Think of it as Google Maps, but specifically for finding stalls inside and around the public market.

### What Users Can Do
- 🗺️ **See all market stalls on a live map** — with real-time open/closed status based on operating hours
- 🔍 **Search and browse stalls** by name, category (e.g., "Meat & Poultry", "Vegetables"), or product
- 🤖 **Ask an AI assistant** ("Aling Suki" / "Kado") questions like "Saan may nagbebenta ng isda?" or "Where can I find rice?"
- ⭐ **Favorite stalls** for quick access later
- 📝 **Report stall issues** (wrong info, closed permanently, etc.)
- 👤 **Manage their profile** (photo, username, display name)

### What Admins Can Do
- 📊 **View a dashboard** with total stalls, active count, pending reports
- 🏪 **Add, edit, and delete stalls** with photos, coordinates, categories, and operating hours
- 🗺️ **Place stall markers on the map** by tapping coordinates
- 📋 **Review and resolve user reports** (pending → reviewed → resolved)

---

## How to Set Up the Project

### Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Flutter SDK | 3.3.0+ | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| Dart SDK | Bundled with Flutter | — |
| Android Studio | Latest | [developer.android.com/studio](https://developer.android.com/studio) |
| Chrome | Latest | For web development |
| Git | Latest | [git-scm.com](https://git-scm.com) |

### Step-by-Step Setup

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd MerkadoGo

# 2. Install all Flutter packages
flutter pub get

# 3. Create the environment file
#    Copy .env.example to .env and fill in ALL the keys
#    (See Part 10 for detailed instructions on getting each key)
cp .env.example .env

# 4. Verify Flutter setup
flutter doctor

# 5. Run on Chrome (for web testing)
flutter run -d chrome

# 6. Run on Android emulator or device
flutter run -d <device-id>
```

### Required API Keys (in `.env`)

You need **3 external services** configured before the app works:

| Service | Key Name | What It Does |
|---------|----------|--------------|
| **Google Gemini AI** | `GEMINI_API_KEY` | Powers the "Aling Suki" AI chatbot |
| **Google Maps** | `GOOGLE_MAPS_API_KEY` | Renders the interactive map |
| **Cloudinary** | `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CLOUDINARY_UPLOAD_PRESET`, `CLOUDINARY_URL` | Stores stall photos and profile images |

Firebase is configured separately through `firebase_options.dart` (already in the repo).

---

## App Flow (High Level)

```
App Launch
  ↓
Splash Screen (animated logo, 2 seconds)
  ↓
┌─ Not logged in ──→ Get Started Screen ──→ Sign In / Create Account
│                                             ↓
│                                      Email Verification
│                                             ↓
├─ Role = "user" ──→ User Portal (Map | Stalls | Profile)
│                       ├── Map: Google Maps with stall markers + AI chatbot
│                       ├── Stalls: Searchable, filterable directory
│                       └── Profile: User info, favorites, sign out
│
└─ Role = "admin" ──→ Admin Portal (Dashboard | Map | Stalls)
                        ├── Dashboard: Stats overview + quick actions
                        ├── Map: Interactive stall placement editor
                        ├── Stalls: Full CRUD management
                        └── Reports: Review/resolve user reports
```

---

## Folder Structure (Simplified)

```
MerkadoGo/
├── lib/
│   ├── main.dart                    ← App entry point
│   ├── firebase_options.dart        ← Firebase config (auto-generated)
│   │
│   ├── core/                        ← Shared utilities & config
│   │   ├── constants/               ← App secrets, strings, category lists
│   │   ├── router/                  ← GoRouter routes & route names
│   │   ├── services/                ← Gemini AI, Cloudinary, Notifications
│   │   ├── theme/                   ← Colors, text styles, spacing
│   │   ├── responsive/              ← Breakpoints & responsive layout helpers
│   │   ├── utils/                   ← Google Maps web loader, stall utilities
│   │   └── widgets/                 ← Main navigation shell, loading overlay
│   │
│   ├── features/                    ← Feature modules (screens & logic)
│   │   ├── auth/                    ← Login, signup, verify, forgot password
│   │   ├── map/                     ← Google Maps screen, indoor map, stall detail
│   │   ├── stalls/                  ← Stall directory listing & categories
│   │   ├── profile/                 ← User profile & edit profile
│   │   ├── report/                  ← User stall report submission
│   │   ├── chat/                    ← AI chatbot domain model & controller
│   │   └── admin/                   ← Admin dashboard, stall CRUD, reports
│   │
│   ├── models/                      ← Shared data models (Stall, User, Report, Chat)
│   ├── providers/                   ← Riverpod providers (auth, stalls, chat, user)
│   └── data/                        ← Seed data scripts
│
├── assets/
│   ├── images/                      ← Logos, illustrations, onboarding art
│   ├── animations/                  ← Lottie animation files
│   └── icons/                       ← Custom icon assets
│
├── web/
│   └── index.html                   ← Web entry point
│
├── android/                         ← Android native config
├── .env                             ← Environment variables (NOT committed)
├── .env.example                     ← Template for .env
└── pubspec.yaml                     ← Dependencies & asset declarations
```

---

*Next: [Part 2 — Tech Stack & Architecture →](./02-TECH-STACK.md)*
