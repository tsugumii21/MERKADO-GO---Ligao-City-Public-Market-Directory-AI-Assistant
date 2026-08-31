# MerkadoGo — Master Project Context & Architecture Reference

**Project:** MerkadoGo — Android market directory & navigation app for the Ligao City Public Market
**Standard:** ISO/IEC 25010:2023 software quality model
**Audience:** AI coding agent / engineering team implementing the Flutter codebase
**Purpose:** This document is the single source of truth for data structures, naming conventions, color mapping, pathfinding logic, and state management rules. Read this in full before writing any implementation code.

---

## 1. Tech Stack & Data Sources

### 1.1 Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter / Dart |
| Backend (data) | Firebase (Firestore/Realtime DB, streamed) |
| Media hosting | Cloudinary (vendor photos, stall imagery) |
| Rendering | `CustomPainter` over an SVG-derived vector layer |

### 1.2 Source-of-Truth Files

| File | Role | Consumed By | Storage Location |
|---|---|---|---|
| `LigaoCity_PublicMarket_Map.svg` | Interactive map — grouped vector shapes, one shape per stall/slot, IDs matching `stall_nodes.json` keys | Map renderer / `CustomPainter` | Bundled app asset |
| `vendor_notes.json` | Vendor profiles: business name, stall number, building/section, full address, primary category, `search_categories[]`, `map_color_hex` | Directory UI, search results, color engine | **Firebase** (live stream) |
| `map_nodes.json` | Pathway graph — every node has `x`, `y` grid coordinates and a `neighbors[]` adjacency list | A* pathfinding graph builder | Bundled app asset |
| `stall_nodes.json` | Maps each stall/slot ID (`id_#` or `slot_[zone]_#`) to its nearest pathway node(s) | Route origin/destination snapping | Bundled app asset |
| `subcategory_search_directory.json` | Multilingual (English / Tagalog / Central Bicolano) keyword → category map | Search engine | Bundled app asset |
| `market_entry_points.json` | 14 physical market entrances mapped to graph nodes | Route origin selection UI | Bundled app asset |

**Storage split, explicitly:** `vendor_notes.json` is the **only** data source that lives in Firebase — it's the one thing that actually changes day-to-day (vendors added, removed, reassigned). Everything else describes the fixed physical structure of the market (walkways, node graph, stall-to-node snapping, entrances, search vocabulary) and does not need a backend round-trip; ship it as a bundled asset and load it once at cold start. This keeps the pathfinding graph and search index available offline, and means the only network dependency on app launch is the vendor stream.

All six files must be parsed and cached in memory at app initialization (cold start), before the map screen mounts. Treat the five bundled files as static reference data refreshed only on app update; `vendor_notes.json` is additionally mirrored live from Firebase (see §3).

---

## 2. Data Structure Reference

### 2.1 `map_nodes.json` — Pathfinding Graph

```json
"node_wm_x1": {
  "x": -3965,
  "y": 1123,
  "neighbors": ["node_ex_t7", "node_wm_e2", "node_wm_t1", "node_wm_x2"]
}
```

- Keys are node IDs following the naming convention in §4.
- `x`/`y` are absolute grid coordinates on the SVG canvas (not lat/lng — this is an indoor vector map, not GPS-based).
- `neighbors` is a bidirectional adjacency list. **Verify symmetry at parse time**: if `A.neighbors` contains `B`, `B.neighbors` should contain `A`. Log/flag any asymmetric edges as data integrity warnings rather than silently failing.
- Build this into a weighted graph where edge weight = Euclidean distance between the two nodes' coordinates. This weight doubles as the A* heuristic's basis (see §6.2).

### 2.2 `stall_nodes.json` — Stall → Node Mapping

Two shapes appear in this file and **must both be handled**:

```json
"id_9": "node_dm_t5"              // single node — unambiguous nearest snap point
"id_15": ["node_ex_t11", "node_ex_t16"]   // array — multiple nearby candidate nodes
```

**Architecture rule:** When the value is an array, treat **index 0 as the primary/nearest snap point** for routing purposes. The remaining entries are fallback or alternate-access candidates (e.g., a stall reachable from more than one aisle). Do not average or pick randomly among them — deterministic index-0 selection keeps routing reproducible and testable.

This file also contains `slot_[zone]_[#]` keys for unassigned/vacant stalls (see §4.2), which resolve to nodes the same way and must be routable even though they carry no vendor data.

### 2.3 `vendor_notes.json` — Vendor Profile Schema

```json
{
  "id": 154,
  "business_name": "MARILOU M GUANZON STORE",
  "stall_id": "id_154",
  "stall_number": "STALL #36",
  "building_or_section": "BUILDING III",
  "address": "STALL #36 BUILDING III MARKET SITE, BAGUMBAYAN",
  "primary_category": "Ingredients",
  "search_categories": ["Rice & Grains", "Ingredients"],
  "map_color_hex": "#9575CD"
}
```

- `stall_id` is the **permanent physical-slot key** — the SVG polygon/element ID and the `stall_nodes.json` key this vendor occupies. It is always populated explicitly on every vendor record, never derived at read time (even though it happens to be reconstructable as `"id_" + id` for officially-assigned vendors) — this keeps rendering/sync code uniform across officially-assigned and slot-assigned vendors, and protects against edge cases like the non-integer split-record `id`s in §9, which don't cleanly derive a single polygon ID. It is set once at assignment time (whether pre-loaded as an official `id_[#]` from the LGU list, or assigned later from the `slot_[zone]_[#]` vacant pool), and is intentionally decoupled from the vendor's own database `id` — `id` identifies the vendor record; `stall_id` identifies the physical space. When a vendor is reassigned or removed, `stall_id` is what tells the state layer which polygon to update.

- `id` is expected to be an integer **except** for a known set of split/duplicate records (`41.1`, `41.2`, `257.2` in the current dataset) representing two physical listings sharing one stall. Treat `id` as a `String` or `double` type in the model, never assume integer parseability.
- `primary_category` drives the map fill/outline color (§5) and is the category shown as the vendor's headline classification.
- `search_categories[]` is a superset used only for search matching — it may include categories beyond `primary_category` (e.g., a sari-sari store that also sells produce). The map color is **never** derived from `search_categories`; only from `primary_category`.
- `map_color_hex` in the source data is a denormalized convenience field. **Do not trust it as the color source of truth in the app** — always resolve color from `primary_category` against the canonical palette in §5, so a single palette update propagates everywhere. Use `map_color_hex` only as a data-validation cross-check during import/seed scripts.

### 2.4 `subcategory_search_directory.json` — Search Directory

```json
"produce": {
  "display_name": "Produce (Fruits & Vegetables)",
  "short_name": "Produce",
  "subcategories": ["Leafy Greens", "Root Crops", "Local Fruits", "Aromatics", "Gourds"],
  "keywords": ["vegetables", "fruits", "cabbage", "gulay", "prutas", "kangkong", "..."]
}
```

- Top-level keys are internal category slugs (snake_case); `display_name` is the UI label; `keywords[]` is the flattened multilingual index (English, Tagalog, and Central Bicolano terms are interleaved in the same array — there is no per-language subdivision in the source data).
- See §7 for how this feeds the search engine.

### 2.5 `market_entry_points.json` — Entrances

```json
{ "entrance_id": 14, "node_id": "node_ex_x2", "description": "Intersection between Wet, Dry, and Rice Market" }
```

Fourteen fixed entries. Present these as the "Where are you entering from?" selector at the start of any route request; `node_id` becomes the A* start node.

---

## 3. State Management Rules

The app must **listen to Firebase data streams** and repaint only the affected SVG polygon(s) via `CustomPainter` — never trigger a full-canvas repaint for a single-stall change. Use a keyed repaint strategy (e.g., a `Map<String, StallRenderState>` diffed against the previous snapshot, with `shouldRepaint` scoped to changed keys only).

| Admin Action | Required Behavior |
|---|---|
| **Add Stall (new vendor → vacant `slot_[zone]_#`)** | Admin selects an available slot from the `slot_[zone]_#` pool and submits a vendor profile. The system writes `stall_id: "slot_[zone]_#"` onto the new vendor record. State layer resolves `primary_category` → `{baseFill, outline}` from the palette (§5) and applies it to the SVG polygon whose element ID matches `stall_id` — that polygon's ID never changes going forward, only the vendor data behind it. |
| **Reassign Stall (vendor swap on existing `stall_id`)** | Admin ends one vendor's occupancy and assigns a new vendor to the same physical `stall_id`. The old vendor doc is removed/archived; the new vendor doc is written with the same `stall_id`. The polygon repaints directly from the old vendor's `primary_category` colors to the new vendor's — it is never reset to Unassigned Gray in between, since the physical slot was never vacant. |
| **Edit Stall** | The stall's map color is **permanently bound to `primary_category`** — it is never set independently. If `primary_category` changes, the state layer must immediately recompute and repaint both `baseFill` and `outline` for that polygon, looked up via `stall_id`. |
| **Delete Stall** | Repaint the polygon matching that vendor's `stall_id` back to the **Unassigned Stalls** profile (`#E2E8F0` fill / `#94A3B8` outline, no accent), and release `stall_id` back into the `slot_[zone]_[#]` pool for reassignment. |

Design implication: color is a **derived value**, never stored as an independent field the admin can hand-edit directly — this guarantees the palette (§5) stays the single source of truth and prevents drift between vendor records and rendered map state.

---

## 4. Naming Conventions

### 4.1 Pathway Nodes

Pattern: `node_[zone]_[intersection][#]`

**Zone prefixes**

| Code | Zone |
|---|---|
| `ea` | Eateries |
| `ex` | Exterior walkways / main perimeter streets |
| `wm` | Wet Market |
| `dm` | Dry Market |
| `rs` | Rice Section |
| `fs` | Fruits Section |

**Intersection suffixes**

| Code | Meaning |
|---|---|
| `_t` | T-junction |
| `_x` | Crossroads (4-way) |
| `_c` | Corner |
| `_e` | Entrance |
| bare `#` | Dead end / terminal edge-of-map point (e.g. `node_ex_1`) |

### 4.2 Stalls & Slots

| Type | Pattern | Example | Notes |
|---|---|---|---|
| Assigned stall | `id_[#]` | `id_154` | Sourced from the official LGU vendor list; permanent |
| Unassigned/vacant slot | `slot_[zone]_[#]` | `slot_dm_001` | Available for admin assignment; renders in Unassigned Gray until filled |

**Total unassigned slot capacity per zone** (for admin dashboard slot-pool counters):

| Zone | Total Slots |
|---|---|
| Wet Market | 53 |
| Eateries | 12 |
| Rice Section | 16 |
| Dry Market | 10 |
| Fruits Section | 6 |

---

## 5. Zone Color Palette (Canonical)

The rendering engine must strictly apply these hex values to SVG `fill` (base) and `stroke` (outline) properties. **Outline stroke width is fixed at 2px** across every zone and every screen density — do not scale it with zoom.

| Zone / Category | Base Fill | Outline |
|---|---|---|
| Produce (Fruits & Vegetables) | `#4CAF50` | `#2E7D32` |
| Meat (Pork & Beef) | `#E57373` | `#C62828` |
| Mixed Meat (Red Meat, Poultry & Processed) | `#C2185B` | `#880E4F` |
| Fish | `#64B5F6` | `#1565C0` |
| Dry Goods (Grains & Clothing) | `#FFD54F` | `#FF8F00` |
| Rice & Grains | `#E5A93C` | `#B27300` |
| Thrift Apparel (Ukay Ukay) | `#3949AB` | `#1A237E` |
| Tailoring & Dress Shop | `#26C6DA` | `#00838F` |
| Eateries (Prepared Food) | `#FF8A65` | `#D84315` |
| Sari Sari / Convenience Retail | `#8BC34A` | `#33691E` |
| Wholesale Snacks & Repacked Supplies | `#8E24AA` | `#4A148C` |
| Ingredients (Spices & Oils) | `#9575CD` | `#4527A0` |
| Coconut & Gata | `#A1887F` | `#4E342E` |
| Specialty Repair (Watch & Jewelry) | `#5C6BC0` | `#283593` |
| Wellness & Spa | `#F06292` | `#AD1457` |
| Salon & Beauty | `#BA68C8` | `#7B1FA2` |
| Miscellaneous (Services & Utilities) | `#4DB6AC` | `#00695C` |
| **Unassigned Stalls** | `#E2E8F0` | `#94A3B8` |

**Map infrastructure & environment** (non-vendor elements — for completeness in the same rendering pipeline):

| Element | Base Fill | Outline |
|---|---|---|
| Pathways (walking corridors) | `#E0E0E0` | `#9E9E9E` |
| Buildings & Facilities | `#B0BEC5` | `#546E7A` |
| Standard Footbridge / Ramp | `#78909C` | `#455A64` |
| Natural River | `#4DD0E1` | `#00838F` |

Implementation note: store this table as a single `Map<String, ZoneColorSet>` constant (e.g. `ZonePalette.produce`) rather than scattering hex literals through widget code, so the palette can be swapped/theme-adjusted in one place.

---

## 6. Pathfinding & Navigation Engine

### 6.1 Graph Construction

On app init, parse `map_nodes.json` into an in-memory graph:

```
Graph {
  Map<String, GraphNode> nodes   // node_id -> {x, y}
  Map<String, List<String>> adjacency
}
```

Then resolve every stall/slot destination via `stall_nodes.json` (§2.2) and every entry gate via `market_entry_points.json` (§2.5) into graph node IDs.

### 6.2 Algorithm: A*

- **Heuristic:** Euclidean distance between current node's `(x, y)` and the goal node's `(x, y)`.
- **Edge cost:** Euclidean distance between adjacent nodes (consistent with the heuristic — admissible and consistent, guaranteeing optimal paths).
- **Start:** the graph node tied to the user-selected entry gate.
- **Goal:** the primary (index-0) node tied to the target stall/slot ID.
- Output: an ordered list of node IDs from start to goal.

### 6.3 Turn Generation (no live GPS)

Since the app has no live GPS tracking indoors, directions must be pre-computed as a static instruction list from the A* path:

1. For each consecutive triplet of nodes `(A, B, C)` in the path, compute the bearing of segment `A→B` and the bearing of segment `B→C`.
2. Compute the signed angular delta between the two bearings.
3. Bucket the delta into a direction:
   - `|delta| < ~15°` → "Go straight"
   - delta positive beyond threshold → "Turn right"
   - delta negative beyond threshold → "Turn left"
   - (Tune the exact threshold against real intersection geometry once the SVG is finalized — some `_x` crossroads may need a "sharp turn" vs "slight turn" distinction.)
4. Collapse consecutive "Go straight" segments into a single instruction with cumulative distance, so the user doesn't get an instruction at every single graph node — only at genuine direction changes and entrance/destination.
5. Emit a final instruction list: `[ {instruction, distance, nodeId}, ... ]` ending at the destination stall.

### 6.4 Visual Rendering

- Draw the resolved path as an overlay polyline on top of the base map via `CustomPainter`, using the same node coordinate space as `map_nodes.json`.
- The route layer repaints independently of the zone/stall layer (§3) — keep them as separate painters or separate `RepaintBoundary`s so recalculating a route never forces a full re-render of all vendor polygons.

---

## 7. Search Engine Logic

- Input: free-text user query (English, Tagalog, or Central Bicolano).
- Process: normalize (lowercase, trim, strip diacritics) and match against the flattened `keywords[]` arrays in `subcategory_search_directory.json` (§2.4).
- On keyword match, resolve to the owning category's `display_name` / internal slug.
- Cross-reference that category against `vendor_notes.json` `search_categories[]` (not `primary_category` alone — a store may be findable under a category it doesn't headline) to produce the result set.
- Rank results: exact business-name matches first, then category/keyword matches, then partial/fuzzy matches (if fuzzy matching is added later, keep it as a distinct fallback stage, not blended into the primary keyword pass).

---

## 8. Non-Functional Notes (ISO/IEC 25010:2023 Alignment)

| Quality Characteristic | Applied Constraint in This Architecture |
|---|---|
| **Performance Efficiency** | Scoped repaints only (§3); precomputed static A* graph avoids runtime graph rebuilding |
| **Reliability** | Adjacency symmetry validation on graph load (§2.1); explicit fallback rule for multi-node stall mappings (§2.2) |
| **Maintainability** | Single canonical color source (§5) resolved from `primary_category`, never hand-set or duplicated from `map_color_hex` |
| **Compatibility** | Firebase stream contracts and SVG polygon IDs kept 1:1 with `stall_nodes.json` keys to avoid silent render mismatches |
| **Usability** | Turn-by-turn instructions collapsed to genuine decision points only (§6.3), avoiding directive noise |
| **Functional Suitability** | Search resolves against the full multilingual keyword set and the vendor's complete `search_categories[]`, not just its primary label |

---

## 9. Known Data Anomalies to Handle Defensively

- Non-integer vendor `id` values (`41.1`, `41.2`, `257.2`) representing split or duplicate stall listings — model `id` as a flexible type, not a strict integer.
- `stall_nodes.json` mixes single-string and array-of-strings values for the same conceptual field — the parser must branch on type at load time (§2.2).
- Some `stall_number` fields carry inconsistent formatting in the source list (`"STALL #15"` vs `"#5"` vs `"11"`) — treat `stall_number` as a display-only string; never parse it for logic.
