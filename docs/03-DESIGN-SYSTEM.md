# Part 3 — Design System

> **RULE: NO GRADIENTS anywhere.** Every color is a flat solid.
> All colors, text styles, and spacing values come from centralized constant files.
> Never use inline hex codes, raw font sizes, or arbitrary pixel padding.

---

## Color Palette

All colors are defined in `lib/core/theme/app_colors.dart`.

### Brand Colors

| Token | Color Name | Hex Code | Swatch | Usage |
|-------|-----------|----------|--------|-------|
| `AppColors.primary` | Forest Green | `#1B5E20` | 🟩 | Primary brand color — buttons, headers, active states, AppBar accents |
| `AppColors.primaryLight` | Soft Mint | `#E8F5E9` | 🟩 | Light green tint — badges, chip backgrounds, active tab indicators |

### Background Colors

| Token | Color Name | Hex Code | Usage |
|-------|-----------|----------|-------|
| `AppColors.canvas` | Warm Off-White | `#F7F7F5` | Full-page scaffold background |
| `AppColors.surface` | Pure White | `#FFFFFF` | Cards, modals, dialogs, input fields |
| `AppColors.surfaceDim` | Soft Sage | `#F1F8E9` | Secondary containers, image placeholders |

### Text Colors

| Token | Color Name | Hex Code | Usage |
|-------|-----------|----------|-------|
| `AppColors.ink` | Deep Charcoal | `#1A241A` | Primary headings & body text |
| `AppColors.inkMuted` | Slate Gray | `#667066` | Subtitles, secondary labels, icons |
| `AppColors.inkSubtle` | Light Gray | `#9E9E9E` | Placeholder text, disabled states, captions |

### Border Colors

| Token | Hex Code | Usage |
|-------|----------|-------|
| `AppColors.border` | `#E2E8E2` | Standard 1px hairline borders on cards, inputs, dividers |
| `AppColors.borderLight` | `#F0F0F0` | Ultra-subtle internal separators |

### Semantic / Status Colors

| Token | Color Name | Hex Code | Usage |
|-------|-----------|----------|-------|
| `AppColors.error` | Crimson Red | `#E53935` | Errors, "Closed" badges, delete actions, "Go" wordmark accent |
| `AppColors.errorLight` | Soft Red | `#FFEBEE` | Error badge background fill |
| `AppColors.errorBorder` | Light Red | `#FFCDD2` | Error badge border stroke |
| `AppColors.warning` | Amber Orange | `#F57F17` | Pending status, maintenance alerts |
| `AppColors.warningLight` | Pale Yellow | `#FFFDE7` | Warning badge background fill |
| `AppColors.warningBorder` | Light Yellow | `#FFE082` | Warning badge border stroke |

### Navigation Colors

| Token | Hex Code | Usage |
|-------|----------|-------|
| `AppColors.navSurface` | `#1A241A` | Dark sidebar background (desktop navigation rail) |
| `AppColors.navActive` | `#4CAF50` | Active navigation item indicator |

### Chat Colors

| Token | Hex Code | Usage |
|-------|----------|-------|
| `AppColors.chatBubbleBot` | `#F5F5F5` | AI assistant response bubble background |
| `AppColors.chatBackground` | `#FAFAFA` | Chat modal background |

---

## How to Use Colors in Code

```dart
import 'package:merkado_go/core/theme/app_colors.dart';

// ✅ CORRECT — always use the token
Container(
  color: AppColors.canvas,
  child: Text('Hello', style: TextStyle(color: AppColors.ink)),
)

// ❌ WRONG — never hardcode hex values
Container(
  color: Color(0xFFF7F7F5),  // DON'T DO THIS
  child: Text('Hello', style: TextStyle(color: Color(0xFF1A241A))),  // DON'T DO THIS
)
```

---

## Typography

All text styles are defined in `lib/core/theme/app_text_styles.dart`.

### Font Families

| Font | Weight Range | Used For |
|------|-------------|----------|
| **Outfit** | w600–w700 | Page titles, section headers |
| **Poppins** | w400–w700 | Body text, captions, labels, buttons, card titles |
| **DM Sans** | w600–w800 | Auth screen headings only |

### Type Scale

| Style Name | Font | Size | Weight | Color | When to Use |
|-----------|------|------|--------|-------|-------------|
| `AppTextStyles.pageTitle` | Outfit | 20px | w700 (Bold) | `ink` | Screen titles in AppBar |
| `AppTextStyles.pageTitleWhite` | Outfit | 20px | w700 (Bold) | White | Titles on dark backgrounds |
| `AppTextStyles.sectionTitle` | Outfit | 16px | w600 (Semi) | `ink` | Section headers within a page |
| `AppTextStyles.cardTitle` | Poppins | 15px | w600 (Semi) | `ink` | Card headers, stall names |
| `AppTextStyles.cardTitlePrimary` | Poppins | 20px | w700 (Bold) | `primary` | Featured/highlighted titles |
| `AppTextStyles.body` | Poppins | 14px | w400 (Regular) | `ink` | Main body text |
| `AppTextStyles.bodyMuted` | Poppins | 13px | w400 (Regular) | `inkMuted` | Secondary body text |
| `AppTextStyles.caption` | Poppins | 12px | w400 (Regular) | `inkMuted` | Metadata, timestamps |
| `AppTextStyles.captionSmall` | Poppins | 11px | w400 (Regular) | `inkSubtle` | Very small metadata |
| `AppTextStyles.label` | Poppins | 12px | w600 (Semi) | `primary` | Active chip labels, links |
| `AppTextStyles.labelSmall` | Poppins | 11px | w600 (Semi) | `inkSubtle` | Uppercase section dividers |
| `AppTextStyles.button` | Poppins | 15px | w600 (Semi) | White | Primary button text |
| `AppTextStyles.statNumber` | Poppins | 24px | w700 (Bold) | `primary` | Dashboard stat numbers |

### How to Use

```dart
import 'package:merkado_go/core/theme/app_text_styles.dart';

Text('Market Stalls', style: AppTextStyles.pageTitle)
Text('Open now', style: AppTextStyles.caption)
Text('Save', style: AppTextStyles.button)
```

---

## Spacing System

All spacing values are defined in `lib/core/theme/app_spacing.dart`.

### Spacing Scale (4px base)

| Token | Value | Typical Usage |
|-------|-------|---------------|
| `AppSpacing.xs` | 4px | Tight spacing between inline elements |
| `AppSpacing.sm` | 8px | Small gaps, icon padding |
| `AppSpacing.md` | 16px | Standard padding, card internal spacing |
| `AppSpacing.lg` | 24px | Section gaps, large card padding |
| `AppSpacing.xl` | 32px | Page-level padding, header spacing |
| `AppSpacing.xxl` | 48px | Hero sections, large visual breaks |

### Border Radius Scale

| Token | Value | Typical Usage |
|-------|-------|---------------|
| `AppSpacing.cardRadius` | 14px | Card corners |
| `AppSpacing.chipRadius` | 20px | Pill-shaped chips and badges |
| `AppSpacing.buttonRadius` | 14px | Button corners |
| `AppSpacing.inputRadius` | 12px | Text field corners |
| `AppSpacing.sheetRadius` | 16px | Bottom sheet top corners |

### How to Use

```dart
import 'package:merkado_go/core/theme/app_spacing.dart';

Container(
  padding: EdgeInsets.all(AppSpacing.md),           // 16px all sides
  margin: EdgeInsets.symmetric(vertical: AppSpacing.sm), // 8px top/bottom
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius), // 14px
  ),
)
```

---

## UI Rules (Must Follow)

### Headers (AppBar)
- Background: `AppColors.surface` (white)
- Elevation: `0` (completely flat)
- `scrolledUnderElevation: 0` (stays flat when scrolling)
- Bottom border: 1.0px `AppColors.border` hairline
- Title: Bold `AppColors.ink`, left-aligned (`centerTitle: false`)
- Subtitle: `AppColors.inkMuted`
- Icons: `AppColors.ink` (dark)
- System overlay: `SystemUiOverlayStyle.dark` (dark status bar icons)

### Cards
- Background: `AppColors.surface`
- Border: 1.0px `AppColors.border`
- Shadow: **NONE** (`elevation: 0`, no `boxShadow`)
- Corner radius: `AppSpacing.cardRadius` (14px)

### Buttons (Primary)
- Background: `AppColors.primary` (solid, not gradient)
- Text: White, `AppTextStyles.button`
- Height: 50px
- Corner radius: 12px
- Elevation: `0`
- Disabled state: reduce opacity

### Chips / Badges
- Active: `AppColors.primary` background, white text
- Inactive: `AppColors.surface` background, `AppColors.inkMuted` text, 1px `AppColors.border`
- Corner radius: `AppSpacing.chipRadius` (20px, pill-shaped)

### Dialogs
- Background: `AppColors.surface`
- Corner radius: 16px
- No shadow
- Title: Bold `AppColors.ink`
- Cancel button: Outlined with `AppColors.border`
- Confirm button: Solid `AppColors.primary` or `AppColors.error` (for destructive actions)

### Desktop Content Constraints
- Form screens: `ConstrainedBox(maxWidth: 720)` centered
- List/dashboard screens: `ConstrainedBox(maxWidth: 1000)` centered
- Use `Align(alignment: Alignment.topCenter)` to center the constrained box

---

## Semantic Status Color Patterns

When showing status indicators, pair **light background + dark text/border**:

| Status | Background | Text/Border | Example |
|--------|-----------|-------------|---------|
| **Open / Active / Resolved** | `primaryLight` | `primary` | Green pill badge |
| **Closed / Error / Delete** | `errorLight` | `error` | Red pill badge |
| **Pending / Warning** | `warningLight` | `warning` | Amber pill badge |
| **Neutral / Default** | `surfaceDim` | `inkMuted` | Gray pill badge |

```dart
// Example: Status badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.primaryLight,  // light green background
    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
    border: Border.all(color: AppColors.primary, width: 0.5),
  ),
  child: Text('Open', style: TextStyle(
    color: AppColors.primary,
    fontWeight: FontWeight.w600,
    fontSize: 12,
  )),
)
```

---

*Next: [Part 4 — Firebase & Data Models →](./04-FIREBASE-AND-DATA.md)*
