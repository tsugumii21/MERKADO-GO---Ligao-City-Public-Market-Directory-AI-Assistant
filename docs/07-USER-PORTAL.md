# Part 7 — Feature: User Portal

The user portal is what regular users see after logging in. It has **3 tabs** (Map, Stalls, Profile) inside a navigation shell, plus additional screens accessible from within.

---

## Navigation Shell (`MainShell`)

**File**: `lib/core/widgets/main_shell.dart`

| Platform | Component |
|----------|-----------|
| Mobile | Bottom navigation bar — 3 icon tabs (Map, Stalls, Profile) |
| Desktop | Left sidebar (240px) — MerkadoGo logo + wordmark, nav items with `AppColors.primaryLight` active indicators |

**Tabs**:
| Index | Icon | Label | Route |
|-------|------|-------|-------|
| 0 | `Icons.map_outlined` | Map | `/home` |
| 1 | `Icons.store_outlined` | Stalls | `/stalls` |
| 2 | `Icons.person_outlined` | Profile | `/profile` |

---

## Screen 1: Map Screen (Home)

**File**: `lib/features/map/presentation/map_screen.dart`
**Route**: `/home`
**Tab**: 0 (default landing page after login)

### What It Does
- Displays a **Google Map** centered on Ligao City Public Market
- Shows **colored markers** for every active stall (color indicates open/closed)
- User can tap a marker to see stall details in a **bottom sheet**
- Includes an **expandable AI chatbot** ("Aling Suki") docked at bottom-right
- Floating **search bar** at the top for searching stalls by name
- **Status chips** showing "X open" / "Y closed" stall counts

### Key Components

| Component | Description |
|-----------|-------------|
| Google Map Widget | Full-screen map with custom markers for each stall |
| Search Bar | Flat bar at top — searches stall names, tapping a result centers map on that stall |
| Layer Toggle | Button to switch between outdoor/indoor map layers |
| Status Chips | Semantic badges showing open (green) and closed (red) stall counts |
| Stall Markers | Colored pins — green = open, red = closed |
| Stall Detail Sheet | Bottom sheet that appears when tapping a marker — shows stall info, photo, hours, products |
| Aling Suki Button | Expandable FAB at bottom-right — opens AI chatbot overlay |

### AI Chatbot ("Aling Suki" / "Kado")

The chatbot is embedded directly in the Map Screen. When the user taps the Aling Suki button:

1. The button smoothly expands into a chat panel (~250ms `Curves.easeOutCubic`)
2. User can type questions in English or Tagalog:
   - "Saan may nagbebenta ng isda?" → AI responds with fish stalls + locations
   - "Which stalls are open right now?" → AI checks operating hours
   - "What products does Aling Maria sell?" → AI lists products
3. AI responses are rendered as **markdown** (supports bold, lists, etc.)
4. Chat history persists while the tab is active
5. Tapping outside or the close button collapses back to the FAB

**Controller**: `lib/features/chat/presentation/chat_controller.dart`
**Domain Model**: `lib/features/chat/domain/chat_message.dart` / `lib/models/chat_message.dart`
**AI Service**: `lib/core/services/gemini_service.dart` (see Part 9 for details)

---

## Screen 2: Indoor Map Screen

**File**: `lib/features/map/indoor_map_screen.dart`
**Route**: `/indoor-map`

### What It Does
- Shows a **2D floor plan** of the indoor public market
- Interactive stall positions overlaid on the floor plan
- Users can tap stalls to see details
- Accessible from the Map Screen via a layer toggle or button

---

## Screen 3: Stall List Screen (Directory)

**File**: `lib/features/stalls/presentation/stall_list_screen.dart`
**Route**: `/stalls`
**Tab**: 1

### What It Does
- Displays all stalls in a **searchable, filterable list**
- Search bar at top for name/product text search
- Horizontal **category filter chips** (All, Vegetables, Meat, Fish, etc.)
- Each stall card shows: photo, name, category, open/closed status, products preview
- Tap a stall card → opens **Stall Detail Sheet**
- Favorite button (heart icon) on each card

### Key Components

| Component | Description |
|-----------|-------------|
| Search Bar | Flat 44px search input with `AppColors.canvas` fill |
| Category Chips | Horizontal scrolling pill chips — active = `AppColors.primary`, inactive = outlined |
| Stall Cards | Flat `AppColors.surface` cards with 1px `AppColors.border`, photo, name, status badge, category tag |
| Favorite Button | Heart icon — toggles stall in user's `favoriteStalls` array in Firestore |
| Empty State | Message when no stalls match search/filter criteria |

### Stall Detail Sheet

**File**: `lib/features/stalls/presentation/stall_detail_sheet.dart`

A **bottom sheet** that slides up when tapping a stall card or map marker:

| Section | Content |
|---------|---------|
| Header | Stall photo (or placeholder), name, category |
| Status | Open/Closed badge with operating hours |
| Products | List of products the stall sells |
| Location | Section/address within the market |
| Days | Which days the stall operates |
| Actions | "Report" button, "Get Directions" (centers map) |

### Stall Category Screen

**File**: `lib/features/stalls/presentation/stall_category_screen.dart`

A filtered view showing stalls of a specific category. Navigated to from category chips or other deep links.

### Controller

**File**: `lib/features/stalls/presentation/stall_list_controller.dart`

Manages:
- Search query text
- Active category filter
- Filtered stall list computation
- Favorite toggle operations

---

## Screen 4: Profile Screen

**File**: `lib/features/profile/presentation/profile_screen.dart`
**Route**: `/profile`
**Tab**: 2

### What It Does
- Displays the current user's profile information
- Shows **profile photo** (from Cloudinary or a default avatar)
- Username, full name, email, member since date
- **Favorite stalls** section — list of the user's favorited stalls
- **Edit Profile** button → navigates to `/edit-profile`
- **Sign Out** button with confirmation dialog

### Layout

```
┌─────────────────────────────────┐
│        Profile Photo            │
│        @username                │
│        Full Name                │
│        email@example.com        │
│        Member since 2026        │
├─────────────────────────────────┤
│  [Edit Profile]                 │
├─────────────────────────────────┤
│  ⭐ Favorite Stalls             │
│  ┌────────────────────────────┐ │
│  │ Stall Card 1               │ │
│  │ Stall Card 2               │ │
│  └────────────────────────────┘ │
├─────────────────────────────────┤
│  [Sign Out]                     │
└─────────────────────────────────┘
```

---

## Screen 5: Edit Profile Screen

**File**: `lib/features/profile/presentation/edit_profile_screen.dart`
**Route**: `/edit-profile`

### What It Does
- Edit display name
- Change username (checks availability in `usernames` collection)
- Change profile photo (pick from gallery/camera → compress → upload to Cloudinary)
- Save button updates Firestore `users/{uid}` document

### Image Upload Flow
1. User taps profile photo → `image_picker` opens gallery/camera
2. Selected image is read as `Uint8List` bytes (web-compatible, no `dart:io`)
3. Image is compressed via `flutter_image_compress`
4. Bytes are uploaded to Cloudinary via REST API (`cloudinary_service.dart`)
5. Returned URL is saved to `users/{uid}.profilePhotoUrl` in Firestore

---

## Screen 6: Report Screen

**File**: `lib/features/report/presentation/report_screen.dart`
(also accessible from: `lib/features/map/presentation/report_screen.dart`)
**Route**: `/report/:id`

### What It Does
- User reports an issue with a specific stall (identified by `:id` path parameter)
- Form with description text field
- On submit: creates a new document in `reports` collection with status `"pending"`
- Shows success confirmation

### Fields
| Field | Description |
|-------|-------------|
| Stall Name | Auto-filled from stall ID (read-only) |
| Description | Free text — what's wrong with the stall |

---

*Next: [Part 8 — Feature: Admin Portal →](./08-ADMIN-PORTAL.md)*
