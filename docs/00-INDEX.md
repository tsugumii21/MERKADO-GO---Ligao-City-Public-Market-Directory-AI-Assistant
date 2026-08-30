# MerkadoGo — Developer Handoff Documentation

> **Ligao City Public Market Directory & AI-Powered Navigation Assistant**
>
> A cross-platform Flutter application featuring real-time Google Maps stall navigation,
> categorized vendor discovery, and a Gemini AI market assistant ("Aling Suki / Kado")
> for conversational product search and local market inquiries.

---

## 📖 Documentation Index

Read these parts **in order**. Each one builds on the previous.

| Part | Title | What You'll Learn |
|------|-------|-------------------|
| [Part 1](./01-PROJECT-OVERVIEW.md) | **Project Overview & Setup** | What the app does, how to clone, install, and run it |
| [Part 2](./02-TECH-STACK.md) | **Tech Stack & Architecture** | Framework, packages, folder structure, state management patterns |
| [Part 3](./03-DESIGN-SYSTEM.md) | **Design System** | Colors, typography, spacing, UI rules — everything visual |
| [Part 4](./04-FIREBASE-AND-DATA.md) | **Firebase & Data Models** | Firestore collections, data models, auth system, image storage |
| [Part 5](./05-ROUTING-AND-NAVIGATION.md) | **Routing & Navigation** | GoRouter setup, role-based redirects, shell routes, route names |
| [Part 6](./06-AUTH-FLOW.md) | **Feature: Authentication Flow** | All 7 auth screens, responsive layout, user registration & login |
| [Part 7](./07-USER-PORTAL.md) | **Feature: User Portal** | Map screen, stall directory, profile, stall reports, favorites |
| [Part 8](./08-ADMIN-PORTAL.md) | **Feature: Admin Portal** | Dashboard, manage stalls, admin map editor, report management |
| [Part 9](./09-SERVICES-AND-AI.md) | **Services & AI Integration** | Gemini AI chatbot, Cloudinary uploads, Google Maps, notifications |
| [Part 10](./10-ENVIRONMENT-AND-DEPLOYMENT.md) | **Environment & Deployment** | `.env` config, Firebase setup, build commands, platform notes |

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. Clone the repo
git clone <repo-url>
cd MerkadoGo

# 2. Install Flutter dependencies
flutter pub get

# 3. Create your .env file (see Part 10 for all required keys)
cp .env.example .env
# Fill in: GEMINI_API_KEY, GOOGLE_MAPS_API_KEY, CLOUDINARY_* keys

# 4. Run on Chrome (web)
flutter run -d chrome

# 5. Run on Android
flutter run -d <device-id>
```

---

## 🗂️ Project At-a-Glance

| Attribute | Value |
|-----------|-------|
| **Framework** | Flutter (Dart) |
| **Min Dart SDK** | `>=3.3.0 <4.0.0` |
| **State Management** | Riverpod |
| **Routing** | GoRouter (role-based) |
| **Backend** | Firebase (Auth + Firestore) |
| **AI Engine** | Google Gemini 2.5 Flash |
| **Image Storage** | Cloudinary |
| **Maps** | Google Maps Flutter |
| **Primary Platform** | Android + Web |

---

## 👥 User Roles

| Role | Access | Entry Point |
|------|--------|-------------|
| **User** | Map, Stall Directory, Profile, Report Stalls | `/home` (Map tab) |
| **Admin** | Dashboard, Manage Stalls, Admin Map Editor, Reports | `/admin` (Dashboard) |

Role is determined by the `role` field in the Firestore `users` collection (`'user'` or `'admin'`).

---

*Last updated: 2026-08-24*
