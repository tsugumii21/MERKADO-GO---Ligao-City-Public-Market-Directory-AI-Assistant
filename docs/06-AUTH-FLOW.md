# Part 6 — Feature: Authentication Flow

## Overview

The auth flow handles user registration, sign-in, email verification, and password reset. All screens use a shared responsive layout wrapper (`AuthLayout`) that adapts between mobile and desktop.

**Files**:
- `lib/features/auth/presentation/` — All auth screens
- `lib/features/auth/presentation/widgets/auth_layout.dart` — Shared responsive wrapper
- `lib/features/auth/presentation/auth_controller.dart` — Auth state controller
- `lib/features/auth/data/auth_repository.dart` — Firebase Auth operations
- `lib/features/auth/domain/user_entity.dart` — User entity

---

## Auth Flow Diagram

```
App Launch
  ↓
SplashScreen (2 sec animation)
  ↓
┌─ Has session? ──→ Check email verified?
│   NO                  │
│   ↓                   ├─ YES → Check role → /home or /admin
│   GetStartedScreen    └─ NO  → /verify-email
│   ↓
│   ┌── Sign In ──→ LoginScreen
│   │                 ↓
│   │          Enter email/username + password
│   │                 ↓
│   │          ┌─ Success? ──→ Check email verified?
│   │          │   NO           ├─ YES → /home or /admin
│   │          │   ↓            └─ NO  → /verify-email
│   │          │  Show error
│   │          └─ "Forgot Password?" → ForgotPasswordScreen
│   │
│   └── Create Account ──→ SignupScreen
│                            ↓
│                     Enter username + name + email + password
│                            ↓
│                     ┌─ Username available? (checks `usernames` collection)
│                     │   NO → show error "Username taken"
│                     │   YES ↓
│                     │  Create Firebase Auth account
│                     │  Create Firestore `users` doc
│                     │  Create Firestore `usernames` doc
│                     │  Send verification email
│                     └─ → /verify-email
│
EmailVerifyScreen
  ↓
  Polls for email verification (auto-reload)
  User clicks "Resend" if needed
  ↓
  Email verified → /home or /admin
```

---

## Screen-by-Screen Breakdown

### 1. Splash Screen

**File**: `lib/features/auth/presentation/splash_screen.dart`
**Route**: `/splash`

**What it does**:
- Shows animated MerkadoGo logo (Lottie animation or scaled image)
- Displays two-tone "Merkado" + "Go" (red) wordmark text
- After ~2 seconds, checks if a Firebase Auth session exists
- Routes to `/get-started` (no session), `/verify-email` (unverified), or `/home`/`/admin` (verified)

---

### 2. Get Started Screen

**File**: `lib/features/auth/presentation/get_started_screen.dart`
**Route**: `/get-started`

**What it does**:
- Brand landing page — first thing new users see
- Two buttons: **"Sign In"** and **"Create Account"**

**Layout**:
| Platform | Layout |
|----------|--------|
| Desktop (≥ 600px) | 50/50 horizontal split — Left: Forest Green (`#1B5E20`) brand panel with logo + tagline — Right: Soft sage (`#F1F8E9`) action panel with buttons |
| Mobile (< 600px) | Top green brand hero (compact) + Bottom action card |

---

### 3. Login Screen

**File**: `lib/features/auth/presentation/login_screen.dart`
**Route**: `/login`

**What it does**:
- **Username OR email** sign-in (unique to this app)
- If user enters a username (no `@`), it looks up the `usernames` collection → gets `uid` → finds email → authenticates
- If user enters an email, authenticates directly
- Shows validation errors for empty fields, wrong password, user not found
- "Forgot Password?" link → `/forgot-password`
- "Don't have an account? Create Account" link → `/signup`

**Fields**:
| Field | Validation |
|-------|-----------|
| Email or Username | Required, non-empty |
| Password | Required, non-empty |

---

### 4. Signup Screen

**File**: `lib/features/auth/presentation/signup_screen.dart`
**Route**: `/signup`

**What it does**:
1. User fills in: Username, Full Name, Email, Password, Confirm Password
2. Checks username availability against `usernames` collection (case-insensitive)
3. Creates Firebase Auth account
4. Creates `users/{uid}` document in Firestore with `role: "user"`
5. Creates `usernames/{username.toLowerCase()}` document
6. Sends email verification link
7. Navigates to `/verify-email`

**Fields**:
| Field | Validation |
|-------|-----------|
| Username | Required, unique (checked against Firestore) |
| Full Name | Required |
| Email | Required, valid email format |
| Password | Required, minimum length |
| Confirm Password | Must match Password |

---

### 5. Email Verify Screen

**File**: `lib/features/auth/presentation/email_verify_screen.dart`
**Route**: `/verify-email`

**What it does**:
- Tells user to check their email for a verification link
- Periodically reloads the Firebase Auth user to check if `emailVerified` changed
- "Resend Email" button to re-send the verification link
- Once verified → navigates to `/home` or `/admin` based on role

---

### 6. Forgot Password Screen

**File**: `lib/features/auth/presentation/forgot_password_screen.dart`
**Route**: `/forgot-password`

**What it does**:
- User enters their email address
- Sends Firebase Auth password reset email
- Shows success confirmation
- "Back to Sign In" link

---

## Shared Auth Layout (`AuthLayout`)

**File**: `lib/features/auth/presentation/widgets/auth_layout.dart`

All auth screens are wrapped in this widget. It provides:

| Property | Description |
|----------|-------------|
| `title` | Screen heading (e.g., "Sign In", "Create Account") |
| `subtitle` | Optional descriptive text below heading |
| `illustrationPath` | Path to illustration asset for desktop left panel |
| `heroTitleWidget` | Override for custom title (used by Get Started only) |
| `child` | The form content |

**Desktop layout** (≥ 600px): 50/50 horizontal split
```
┌──────────────────────┬──────────────────────┐
│                      │                      │
│   Green brand panel  │   White/sage form    │
│   with logo +        │   panel with fields  │
│   illustration       │   and buttons        │
│                      │                      │
└──────────────────────┴──────────────────────┘
```

**Mobile layout** (< 600px): Stacked
```
┌──────────────────────┐
│  Green brand hero    │
│  (compact, ~120px)   │
├──────────────────────┤
│                      │
│  Sage card with      │
│  form fields and     │
│  buttons (scrollable)│
│                      │
└──────────────────────┘
```

---

## Auth Controller & Repository

### Auth Controller (`lib/features/auth/presentation/auth_controller.dart`)

Riverpod `StateNotifier` that manages auth operations:
- `signIn(emailOrUsername, password)` — handles both email and username login
- `signUp(username, fullName, email, password)` — full registration flow
- `signOut()` — sign out + clear local state
- `sendPasswordResetEmail(email)` — trigger password reset
- `sendEmailVerification()` — resend verification email

### Auth Repository (`lib/features/auth/data/auth_repository.dart`)

Direct Firebase Auth + Firestore operations:
- `signInWithEmail(email, password)` — `FirebaseAuth.signInWithEmailAndPassword`
- `createUser(email, password)` — `FirebaseAuth.createUserWithEmailAndPassword`
- `createUserDocument(uid, data)` — writes to `users/{uid}`
- `reserveUsername(username, uid)` — writes to `usernames/{username}`
- `checkUsernameAvailability(username)` — reads `usernames/{username}`
- `getUserByUsername(username)` — resolves username → email for sign-in
- `sendVerificationEmail()` — `currentUser.sendEmailVerification()`
- `sendPasswordReset(email)` — `FirebaseAuth.sendPasswordResetEmail`

---

*Next: [Part 7 — Feature: User Portal →](./07-USER-PORTAL.md)*
