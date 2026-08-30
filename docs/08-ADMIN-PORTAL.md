# Part 8 — Feature: Admin Portal

The admin portal is a separate section of the app accessible only to users with `role: "admin"` in their Firestore user document. It has its own navigation shell and 6 screens for managing market stalls and reports.

---

## Admin Navigation Shell (`AdminMainShell`)

**File**: `lib/features/admin/presentation/admin_main_shell.dart`

| Platform | Component |
|----------|-----------|
| Mobile (< 600px) | Bottom navigation bar — 3 tabs (Dashboard, Map, Stalls), 56px tall |
| Desktop (≥ 600px) | Left sidebar (240px) with admin branding + navigation |

### Desktop Sidebar Layout

```
┌─────────────────────────┐
│  [Logo]  MerkadoGo      │  ← Two-tone wordmark
│  ┌────────────────────┐ │
│  │ ADMIN Portal       │ │  ← Pill badge
│  └────────────────────┘ │
│                         │
│  MAIN MENU              │  ← Section header
│  ● Dashboard            │  ← Active = primaryLight pill
│  ○ Market Map           │
│  ○ Manage Stalls        │
│                         │
│  MANAGEMENT             │  ← Section header
│  + Add New Stall        │  ← Shortcut link
│  📋 Stall Reports       │
│                         │
│  ─────────────────────  │
│  👤 Admin Session       │  ← Pinned at bottom
│  [Sign Out]             │
└─────────────────────────┘
```

---

## Screen 1: Admin Dashboard

**File**: `lib/features/admin/presentation/admin_dashboard_screen.dart`
**Route**: `/admin`
**Tab**: 0

### What It Shows

| Section | Content |
|---------|---------|
| **Welcome Banner** | "Welcome back, Admin" with ADMIN badge, current date |
| **Stat Cards** (clickable) | Total Stalls, Active Stalls, Pending Reports, Total Categories |
| **Quick Actions Grid** | Tiles that link to: Add Stall, Manage Stalls, View Reports, Market Map Editor |

### Stat Cards

Each stat card is a flat `AppColors.surface` container with:
- Semantic icon in a colored circle (e.g., store icon in `surfaceDim`/`primary` circle)
- Large number (`AppTextStyles.statNumber`)
- Label text
- Tap handler → navigates to the relevant screen

| Card | Icon Color Pair | Tap Action |
|------|----------------|-----------|
| Total Stalls | `surfaceDim` bg / `primary` icon | → `/admin/stalls` |
| Active Stalls | `primaryLight` bg / `primary` icon | → `/admin/stalls` |
| Pending Reports | `errorLight` bg / `error` icon | → `/admin/reports` |
| Total Categories | `warningLight` bg / `warning` icon | — |

### Data Source
- Queries `stalls` collection for total and active counts
- Queries `reports` collection where `status == 'pending'` for pending count
- Counts unique categories from all stalls

---

## Screen 2: Admin Map Screen

**File**: `lib/features/admin/presentation/admin_map_screen.dart`
**Route**: `/admin/map`
**Tab**: 1

### What It Does
- Interactive Google Map showing all stall markers
- Admin can tap a marker → opens **bottom action sheet** with stall info + actions
- Admin can **long-press on the map** to add a new stall at those coordinates
- Floating search bar to search stalls by name
- Open/Closed count badge (floating pill)
- Recenter button

### Bottom Action Sheet (on marker tap)

```
┌─────────────────────────────────┐
│  [Stall Photo]  Stall Name     │
│                 Category Badge  │
│                                 │
│  📍 Section A, Stall 12        │
│  🕐 06:00 - 18:00              │
│  ● Open                        │
│                                 │
│  [✏️ Edit]  [📍 Move]  [🗑️ Delete] │
└─────────────────────────────────┘
```

### Actions Available

| Action | What It Does |
|--------|-------------|
| **Edit** | Navigates to `/admin/stalls/{id}/edit` |
| **Move Location** | Opens coordinate picker dialog — admin taps new spot on map |
| **Delete** | Confirmation dialog → removes stall from Firestore |
| **Long-press Map** | Opens "Add Stall" dialog with pre-filled coordinates → navigates to add stall form |

---

## Screen 3: Manage Stalls Screen

**File**: `lib/features/admin/presentation/manage_stalls_screen.dart`
**Route**: `/admin/stalls`
**Tab**: 2

### What It Does
- Full list of all stalls with search and category filtering
- Each stall card has quick **Edit** and **Delete** action buttons

### Layout

```
┌─────────────────────────────────┐
│  AppBar: Manage Stalls          │
│  Subtitle: X stalls registered  │
├─────────────────────────────────┤
│  🔍 Search stalls...            │  ← 44px flat search bar
├─────────────────────────────────┤
│  [All] [Meat] [Fish] [Veg] ... │  ← Category filter chips (horizontal scroll)
├─────────────────────────────────┤
│  [Dry Goods] [Fresh] [Cooked]  │  ← Subcategory chips (when category selected)
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │ 📷 Stall Name           │   │
│  │ Category • Status Badge │   │
│  │ Products: ...           │   │
│  │           [✏️] [🗑️]     │   │  ← Edit (surfaceDim/primary) and Delete (errorLight/error)
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Next stall card...      │   │
│  └─────────────────────────┘   │
├─────────────────────────────────┤
│  [+ Add Stall] FAB             │
└─────────────────────────────────┘
```

### Search
- Filters stalls by name, category, products, or tags
- Uses case-insensitive regex matching

### Delete Flow
1. Admin taps 🗑️ button on a stall card
2. Confirmation dialog: "Are you sure you want to delete [Stall Name]?"
3. Cancel / Delete buttons
4. On confirm → deletes document from `stalls` collection

---

## Screen 4: Add / Edit Stall Screen

**File**: `lib/features/admin/presentation/add_edit_stall_screen.dart`
**Route**: `/admin/stalls/add` (new) or `/admin/stalls/:id/edit` (edit)

### What It Does
- Form for creating a new stall or editing an existing one
- If `stallId` is provided in route params → loads existing stall data and pre-fills the form
- On save → creates or updates document in `stalls` collection

### Form Fields

| Field | Type | Description |
|-------|------|-------------|
| **Stall Photo** | Image picker | Tap placeholder → camera/gallery → compress → upload to Cloudinary |
| **Stall Name** | Text input | Required |
| **Categories** | Multi-select chips | Pick from predefined market categories |
| **Products** | Text input (comma-separated) | Products the stall sells |
| **Address / Section** | Text input | Location within market |
| **Operating Hours** | Time pickers | Open time + Close time |
| **Operating Days** | Day selector chips | Mon, Tue, Wed, Thu, Fri, Sat, Sun |
| **Status** | Toggle | Active / Inactive |
| **Coordinates** | Lat/Lng inputs | GPS position for map marker |

### Desktop Layout
- Form is wrapped in `ConstrainedBox(maxWidth: 720)` centered on screen
- Provides comfortable reading width on wide monitors

### Image Upload Flow (same as profile)
1. Tap photo placeholder → `image_picker` opens
2. Image read as `Uint8List` (web-compatible)
3. Compressed via `flutter_image_compress`
4. Uploaded to Cloudinary REST API
5. URL saved in `stalls/{id}.photoUrls` array

---

## Screen 5: Reports Screen

**File**: `lib/features/admin/presentation/reports_screen.dart`
**Route**: `/admin/reports`

### What It Does
- Displays all user-submitted stall reports
- Filter by status: All, Pending, Reviewed, Resolved
- Each report card shows: stall name, description, status badge, submission date
- Admin can take action on each report

### Filter Chips

| Filter | Shows |
|--------|-------|
| All | Every report regardless of status |
| Pending | Only `status: "pending"` reports (needs attention) |
| Reviewed | Only `status: "reviewed"` reports (acknowledged but not fixed) |
| Resolved | Only `status: "resolved"` reports (completed) |

### Report Card Actions

| Action | Visible When | What It Does |
|--------|-------------|-------------|
| **Review** | Status = "pending" | Changes status to "reviewed" |
| **Resolve** | Status = "pending" or "reviewed" | Changes status to "resolved" |
| **Delete** | Any status | Confirmation dialog → removes report from Firestore |

### Status Badge Colors

| Status | Background | Text |
|--------|-----------|------|
| Pending | `warningLight` | `warning` |
| Reviewed | `primaryLight` | `primary` |
| Resolved | `surfaceDim` | `inkMuted` |

### Desktop Layout
- Report list wrapped in `ConstrainedBox(maxWidth: 1000)` centered on screen

---

## Admin Sign Out

Available from:
- Desktop sidebar → bottom "Admin Session" tile
- Dashboard screen → Sign Out button in AppBar

**Flow**:
1. Admin taps Sign Out
2. Confirmation dialog: "Are you sure you want to sign out?"
3. Cancel / Sign Out buttons
4. On confirm → `FirebaseAuth.signOut()` → navigates to `/login`

---

*Next: [Part 9 — Services & AI Integration →](./09-SERVICES-AND-AI.md)*
