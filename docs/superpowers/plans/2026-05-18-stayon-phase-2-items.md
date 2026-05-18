# StayOn Phase 2 — Items CRUD + Home Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed-in user can add, edit, view, archive, soft-delete (with undo), and see their own items on a date-grouped Home dashboard. All data persisted in Supabase under RLS. No attachments / reminders / OCR — those are later phases.

**Architecture:** UI → Riverpod controller → Repository (interface) → Supabase client. No local DB cache in this phase (see §J for the deliberate decision to defer Drift). Stream-based reactive list via Supabase's realtime channel for the current user's items. Forms validate locally; backend errors translate to user-friendly snackbars via a domain `ItemException` (mirrors the Phase 1 `AuthException` pattern).

**Tech Stack:** `supabase_flutter` ^2.12 · `flutter_riverpod` ^2.5 · `go_router` ^14 · `freezed` ^2.5 · `intl` ^0.19 · `mocktail` ^1 (no new dependencies — everything already pinned in Phase 0).

**Source spec:** [`docs/superpowers/specs/2026-05-18-stayon-mvp-design.md`](../specs/2026-05-18-stayon-mvp-design.md) §3–§11
**Previous phases:** [`v0.1-scaffold`](2026-05-18-stayon-mvp.md) · [`v0.2-auth`](2026-05-18-stayon-phase-1-auth.md)

---

## 1. Scope

### In scope
- **Add Item** — modal sheet form: name, category (preset, no custom), date type (`expires` / `renews` / `due`), `target_date`, notes (optional), assignee label (optional free text), amount in PHP (optional)
- **Edit Item** — same form prefilled
- **View Item Detail** — full-screen route with header card, all fields, "X days from now / overdue by X" badge, and an action row (Edit · Mark renewed · Archive · Delete)
- **Mark renewed** — convenience action that opens the Edit form with the date field focused (lets the user advance the next `target_date`)
- **Home dashboard** — real list grouped into **Overdue · This week · This month · Later** with empty / loading / error states; sorted by `target_date` ascending within each group
- **Archive** — sets `status='archived'`; hidden from Home; no Archive-list UI yet (deferred to Phase 6)
- **Soft-delete** — sets `status='trashed'`; shows undo snackbar for 5 seconds with Restore action
- **Categories** — fixed 9 presets per spec §9 with color-coded chips: Warranty, Subscription, ID/License, Insurance, Medicine, Grocery, Bill, Document, Other
- **Amount** — stored as `amount_minor` (int, centavos) + `currency_code` (default `'PHP'`); displayed as `₱1,234.50` via `intl.NumberFormat.currency`
- **Ownership** — every item carries `owner_id = auth.uid()`; RLS forbids cross-user reads/writes
- **Realtime updates** — Home list updates when another device of the same user adds/edits/deletes
- **Wire FAB to Add Item** — replaces the "Add Item arrives in Phase 2" snackbar

### Out of scope (deferred — do not build in Phase 2)
- Attachments (Phase 3) · OCR / AI extraction (Phase 5 + V2) · local push notifications (Phase 4)
- Family sharing / shared households (Phase 1b / V2)
- Calendar sync · widgets · IAP · Google/Apple sign-in
- Account deletion UI (Phase 6)
- Settings screen / theme switcher (Phase 6)
- Dedicated Archive-list and Trash-list screens (Phase 6 — Phase 2 only writes the state)
- The Trash 30-day `pg_cron` purge job (Phase 6)
- Calendar tab / Alerts tab content (Phase 5)
- Family tab content (Phase 6)
- Insights / spend analytics (V1.5; `amount_minor` is captured in this phase so it ships without migration)
- Search (Phase 5)
- Tagalog / non-English UI

---

## 2. Technical architecture

### Architecture decisions

| Decision | Choice | Reason |
|---|---|---|
| Local cache (Drift) | **Defer to Phase 2b** | Supabase free tier + a typical user with <200 items keeps the dashboard query under ~200 ms; the complexity of a sync engine (schema versioning, conflict resolution, web sqlite3 WASM) is not justified for beta. We add Drift only if beta users report offline pain. |
| Realtime updates | Supabase realtime channel filtered to `owner_id = auth.uid()` | Free on the Supabase Free tier; one channel; minor bandwidth; needed for "edit on device A, see on device B" UX once Phase 1b unlocks multi-device sign-in. |
| Form validation | Reuse Phase 1 `Form` + `TextFormField.validator` pattern | No new dep; consistent UX with auth forms. |
| Error model | Domain `ItemException(code, message)` thrown by repository | Mirrors `AuthException`; UI translates to snackbars. |
| State shape | Per-screen Riverpod controllers + a single `itemsStreamProvider` for the Home list | Matches Phase 1 layering; no global app state. |

### Folder layout (additions only)

```
lib/
  core/
    models/
      item.dart                # freezed model
      item_category.dart       # enum + UI helpers (color, label, icon)
      item_date_type.dart      # enum
      item_status.dart         # enum
      money.dart               # tiny PHP formatting helper
  features/
    items/
      data/
        item_repository.dart           # interface + ItemException
        supabase_item_repository.dart  # impl
      controllers/
        item_providers.dart            # itemRepositoryProvider, itemsStreamProvider
        item_form_controller.dart      # AsyncNotifier for add/update
        item_actions_controller.dart   # AsyncNotifier for archive/delete/restore
      ui/
        item_form_sheet.dart           # Add + Edit modal
        item_detail_screen.dart        # /item/:id
        widgets/
          category_chip.dart
          category_chip_selector.dart
          date_type_segment.dart
          amount_field.dart
          item_card.dart
          item_card_section.dart       # "Overdue", "This week", ...
          empty_home_state.dart
supabase/migrations/
  0002_items.sql
  0003_items_rls.sql
test/
  core/models/
    item_test.dart                     # serialization round-trip
    money_test.dart
  features/items/
    item_repository_test.dart          # mocked Supabase
    item_form_sheet_test.dart          # widget validation
    item_actions_controller_test.dart
    home_grouping_test.dart            # pure-Dart logic test
```

### Layering rules (unchanged from Phase 1)
- UI → controller (Riverpod) → repository (interface) → Supabase service
- No business logic in widgets
- All async ops throw domain exceptions; controllers wrap with `AsyncValue.guard`
- Models are `freezed`; never `Map<String, dynamic>` past the repository boundary

---

## 3. Database plan

### Migration `0002_items.sql`

```sql
-- StayOn migration 0002: items table + indexes
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  category text not null check (category in (
    'warranty','subscription','id_license','insurance',
    'medicine','grocery','bill','document','other'
  )),
  date_type text not null check (date_type in ('expires','renews','due')),
  target_date date not null,
  notes text,
  assignee_label text,
  amount_minor int,
  currency_code text not null default 'PHP',
  status text not null default 'active' check (status in ('active','archived','trashed')),
  trashed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Dashboard sort + filter
create index if not exists items_owner_status_date_idx
  on public.items (owner_id, status, target_date);

-- Trash purge job (added in Phase 6) will use this index
create index if not exists items_trashed_at_idx
  on public.items (trashed_at)
  where status = 'trashed';

-- Auto-update `updated_at` on every UPDATE
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists items_touch_updated_at on public.items;
create trigger items_touch_updated_at
  before update on public.items
  for each row execute function public.touch_updated_at();
```

### Migration `0003_items_rls.sql`

```sql
-- StayOn migration 0003: RLS on items
alter table public.items enable row level security;

-- Owner can read their own items.
create policy "items_select_own" on public.items
  for select using (auth.uid() = owner_id);

-- Owner can insert items only with their own auth uid as owner_id.
create policy "items_insert_own" on public.items
  for insert with check (auth.uid() = owner_id);

-- Owner can update their own items; owner_id is immutable.
create policy "items_update_own" on public.items
  for update using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Owner can hard-delete their own items (Phase 2 uses soft-delete via
-- status='trashed'; this policy enables the Phase 6 purge job and any
-- future "Empty trash" UI).
create policy "items_delete_own" on public.items
  for delete using (auth.uid() = owner_id);
```

### Security checklist for this phase

- [ ] RLS **enabled** on `items` BEFORE the client ever inserts a row (run `0003` immediately after `0002`)
- [ ] No service-role key in app, env file, or CI
- [ ] No raw SQL from the client — all writes go through Supabase's typed client (parameterized)
- [ ] `owner_id` is set from `auth.uid()` at insert time; we never trust client-provided owner_id
- [ ] `currency_code` defaults to `'PHP'` but stored explicitly so multi-currency in V2 needs no migration

### What we deliberately are NOT adding now
- Foreign-key to a `categories` table — categories are a fixed enum string (custom categories = V2)
- A `tags` array column — tags are V3
- A `recurring_interval` column — recurring auto-renewal is V1.5
- Full-text search index — added in Phase 5 when Search UI lands

---

## 4. UI/UX plan

### Visual language reminder (carry-over from spec §3)
- Cream background (`#FAF6EE`), forest green primary (`#0F3D2E`), Nunito Sans throughout
- 16 px rounded card corners, soft 8 px green-tinted shadow
- One green FAB centered in the bottom nav
- Coral (`#FF7A5C`) used sparingly for attention (overdue badge)

### Screen inventory and states

| Screen | Empty | Loading | Error | Loaded |
|---|---|---|---|---|
| **Home dashboard** | "No items yet — tap + to add your first item" with FAB pulse | Skeleton placeholder cards for 2 sections | "Couldn't load your items" + Retry button | Sectioned list (Overdue / This week / This month / Later) |
| **Add Item modal** | n/a | Submit button shows spinner | Inline field error + snackbar on backend failure | Tap Save → toast + close |
| **Edit Item modal** | n/a | Same as Add | Same as Add | Same as Add |
| **Item Detail** | n/a | Centered spinner | "Item not found" + Back | Header card + field rows + action row |

### Home dashboard layout

```
+----------------------------------------+
| Good morning,                          |
| Rohan                                  |
|                                        |
| THIS WEEK                              |
| 3 items due soon                       |
| All caught up · 18 active              |
|                                        |
| Overdue (2)                            |
| [card] [card]                          |
|                                        |
| This week (3)                          |
| [card] [card] [card]                   |
|                                        |
| This month (4)                         |
| [card] ...                             |
|                                        |
| Later (9)                              |
| [card] ...                             |
|                                        |
+----------------------------------------+
| Home  Calendar  [+]  Alerts  Family    |
+----------------------------------------+
```

Header card already exists from Phase 1 (greeting + empty card). In Phase 2, the empty card is replaced by:
1. "This week" hero card (matching the hero image's green card) with a live count of items in the **This week** + **Overdue** buckets
2. Sectioned scrollable list using `ListView` of section headers + `ItemCard`s

### `ItemCard` anatomy

```
+-----------------------------------------+
| [color chip]  CATEGORY                  |
| ─                                       |
| Item name (titleMd, 1-2 lines)          |
| Expires in 3 days · May 25              |
+-----------------------------------------+
```

- Background uses the per-category surface color (peach / butter / sky / mint / etc.) at 60% opacity
- Tap → navigate to `/item/:id`
- Long-press → action sheet (Archive / Delete) — secondary access path; primary access is via Item Detail's action row

### Add / Edit Item modal

A `showModalBottomSheet` with `isScrollControlled: true` and `useSafeArea: true`. Sections separated by 24 px gaps:

1. **Name** (`TextFormField`, autofocus on Add mode; validator: 1–120 chars after trim)
2. **Category** (`CategoryChipSelector` — horizontal scroll of all 9 chips, one selected)
3. **Date type** (segmented control: Expires / Renews / Due)
4. **Target date** (`InkWell` opening `showDatePicker`; required; can be in the past for already-expired)
5. **Amount** (`AmountField`: optional, accepts decimals, formatted as `₱X,XXX.XX` on blur; stored as minor units)
6. **Assignee** (optional `TextFormField`, max 60 chars)
7. **Notes** (optional `TextFormField` multi-line, max 500 chars)

Footer: Cancel (text button) · Save (`FilledButton`).

### Item Detail action row

`Row` at the bottom of the screen with five buttons:
- **Edit** (opens form prefilled)
- **Mark renewed** (opens form with the date field auto-focused; no other change)
- **Archive** (status → archived → snackbar "Archived · Undo" 5s)
- **Delete** (status → trashed → snackbar "Deleted · Restore" 5s)
- **Back arrow** in app bar to return to Home

### "X days from now" formatting

Single helper `String relativeDateLabel(DateTime target, {DateTime? now})`. Tested separately.

| Δ days | Label |
|---|---|
| -∞ … -1 | "Overdue by N day(s)" |
| 0 | "Due today" |
| 1 | "Due tomorrow" |
| 2 … 6 | "Due in N days" |
| 7 … 30 | "Due in ~N weeks" (rounded) |
| 31 … 365 | "Due in N months" |
| 365 + | "Due in over a year" |

The dashboard's **section bucket** uses the same date math (also unit-tested):
- Overdue: `target < today`
- This week: `today ≤ target ≤ today + 6 days`
- This month: `target ≤ today + 30 days`
- Later: `target > today + 30 days`

Trashed items never appear; archived items never appear; Home is `status = 'active'` only.

---

## 5. Tests

TDD-first where logic exists. Each task that introduces logic writes the failing test before the implementation.

### Unit tests (pure Dart, no Flutter binding)
- `item_test.dart` — model JSON round-trip with all optional fields null + populated
- `money_test.dart` — `pesoFromMinor(int? minor) → String` (e.g., `null → ''`, `0 → '₱0.00'`, `12345 → '₱123.45'`, `9999999 → '₱99,999.99'`)
- `home_grouping_test.dart` — given a list of items and a fixed "now", produces the correct 4-bucket grouping with sort-within-group by `target_date` ascending
- `relative_date_label_test.dart` — every branch of the table above

### Widget tests
- `item_form_sheet_test.dart`:
  - Validation: empty name blocks submit
  - Validation: amount accepts `12.34`, `12`, ``, rejects `abc`
  - Add mode submits with default values (today's date, "other" category)
  - Edit mode prefills all fields
- `item_card_test.dart` — renders category label, name, and relative-date label

### Repository tests (mocked Supabase client)
- `add(item)` calls `_client.from('items').insert(...)` with correct payload
- `add` surfaces RLS denial as `ItemException(code='rls', ...)`
- `update(id, patch)` calls the right method, updates `updated_at` implicitly
- `archive(id)` sets `status='archived'`; `trash(id)` sets `status='trashed'` + `trashed_at`; `restore(id)` clears them
- `watchActive()` filters out non-active statuses

### Integration / runtime
- Playwright smoke after each UI task (web-server + navigate + snapshot + console-clean)
- Final Phase-2 manual smoke: add 3 items spanning all 4 buckets; verify grouping; archive one; delete one with Undo; restore via snackbar; reopen app; verify persistence

---

## 6. Quality gates (per task)

Every coding task ends with:

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
```

Every task that ships UI also runs:

```bash
flutter build web --dart-define-from-file=.env.local
```

Playwright smoke is run at the end of major UI tasks (Tasks 9, 12, 15) and at the end of the phase.

CI on every push: format + analyze + test (web build is exit-gate only — too slow for CI).

---

## 7. Build tasks (bite-sized, TDD where applicable)

### Manual prerequisites

#### Task M1: Apply 0002 migration in Supabase
- [ ] Step 1: In Supabase SQL Editor, paste the contents of `supabase/migrations/0002_items.sql`. Run.
- [ ] Step 2: Verify in Table Editor: `items` table exists with all columns and check constraints. No RLS badge yet (that's the next step).

#### Task M2: Apply 0003 migration in Supabase
- [ ] Step 1: Same flow with `0003_items_rls.sql`.
- [ ] Step 2: Verify: green **RLS enabled** badge on `items`; Authentication → Policies shows `items_select_own`, `items_insert_own`, `items_update_own`, `items_delete_own`.

I'll pause and instruct you to run these manually before any code that depends on them lands.

---

### Code tasks

#### Task 1: ItemCategory enum + UI helpers

**Files:** Create `lib/core/models/item_category.dart`

- [ ] Step 1: Write the file
```dart
import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

enum ItemCategory {
  warranty('warranty', 'Warranty', AppColors.catWarranty, Icons.shield_outlined),
  subscription('subscription', 'Subscription', AppColors.catSubscription,
      Icons.subscriptions_outlined),
  idLicense('id_license', 'ID / License', AppColors.catDocument,
      Icons.badge_outlined),
  insurance('insurance', 'Insurance', AppColors.catInsurance,
      Icons.health_and_safety_outlined),
  medicine('medicine', 'Medicine', AppColors.catMedicine,
      Icons.medication_outlined),
  grocery('grocery', 'Grocery', AppColors.catGrocery,
      Icons.local_grocery_store_outlined),
  bill('bill', 'Bill', AppColors.catBill, Icons.receipt_long_outlined),
  document('document', 'Document', AppColors.catDocument,
      Icons.description_outlined),
  other('other', 'Other', AppColors.catOther, Icons.label_outline);

  const ItemCategory(this.dbValue, this.label, this.surface, this.icon);
  final String dbValue;
  final String label;
  final Color surface;
  final IconData icon;

  static ItemCategory fromDb(String value) =>
      ItemCategory.values.firstWhere(
        (c) => c.dbValue == value,
        orElse: () => ItemCategory.other,
      );
}
```
- [ ] Step 2: `flutter analyze` clean, then commit
```bash
git add lib/core/models/item_category.dart
git commit -m "feat(models): ItemCategory enum with UI helpers"
```

#### Task 2: ItemDateType + ItemStatus enums

**Files:** Create `lib/core/models/item_date_type.dart` and `lib/core/models/item_status.dart`

- [ ] Step 1: Write `item_date_type.dart`
```dart
enum ItemDateType {
  expires('expires', 'Expires'),
  renews('renews', 'Renews'),
  due('due', 'Due');

  const ItemDateType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ItemDateType fromDb(String v) =>
      ItemDateType.values.firstWhere((e) => e.dbValue == v);
}
```
- [ ] Step 2: Write `item_status.dart`
```dart
enum ItemStatus {
  active('active'),
  archived('archived'),
  trashed('trashed');

  const ItemStatus(this.dbValue);
  final String dbValue;

  static ItemStatus fromDb(String v) =>
      ItemStatus.values.firstWhere((e) => e.dbValue == v);
}
```
- [ ] Step 3: Format + analyze + commit
```bash
git add lib/core/models/item_date_type.dart lib/core/models/item_status.dart
git commit -m "feat(models): ItemDateType + ItemStatus enums"
```

#### Task 3: Item freezed model + JSON test (TDD)

**Files:** Create `test/core/models/item_test.dart` (failing), `lib/core/models/item.dart` (implement), runs `build_runner`.

- [ ] Step 1: Write the failing test first
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';

void main() {
  test('round-trips via JSON with all fields populated', () {
    final item = Item(
      id: 'a',
      ownerId: 'o',
      name: 'PhilHealth',
      category: ItemCategory.idLicense,
      dateType: ItemDateType.renews,
      targetDate: DateTime.utc(2026, 12, 31),
      notes: 'Annual',
      assigneeLabel: 'Mom',
      amountMinor: 250000,
      currencyCode: 'PHP',
      status: ItemStatus.active,
      trashedAt: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final json = item.toJson();
    expect(Item.fromJson(json), item);
  });

  test('round-trips with nullables omitted', () {
    final item = Item(
      id: 'a',
      ownerId: 'o',
      name: 'Bread',
      category: ItemCategory.grocery,
      dateType: ItemDateType.expires,
      targetDate: DateTime.utc(2026, 5, 25),
      notes: null,
      assigneeLabel: null,
      amountMinor: null,
      currencyCode: 'PHP',
      status: ItemStatus.active,
      trashedAt: null,
      createdAt: DateTime.utc(2026, 5, 18),
      updatedAt: DateTime.utc(2026, 5, 18),
    );
    expect(Item.fromJson(item.toJson()), item);
  });
}
```
- [ ] Step 2: Run, confirm failure (`Item` undefined)
```bash
flutter test test/core/models/item_test.dart
```
- [ ] Step 3: Write `lib/core/models/item.dart`
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_category.dart';
import 'item_date_type.dart';
import 'item_status.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required String id,
    @JsonKey(name: 'owner_id') required String ownerId,
    required String name,
    @JsonKey(fromJson: _catFromJson, toJson: _catToJson)
    required ItemCategory category,
    @JsonKey(name: 'date_type', fromJson: _dtFromJson, toJson: _dtToJson)
    required ItemDateType dateType,
    @JsonKey(name: 'target_date', fromJson: _dateFromJson, toJson: _dateToJson)
    required DateTime targetDate,
    String? notes,
    @JsonKey(name: 'assignee_label') String? assigneeLabel,
    @JsonKey(name: 'amount_minor') int? amountMinor,
    @JsonKey(name: 'currency_code') @Default('PHP') String currencyCode,
    @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
    @Default(ItemStatus.active)
    ItemStatus status,
    @JsonKey(name: 'trashed_at') DateTime? trashedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

ItemCategory _catFromJson(String v) => ItemCategory.fromDb(v);
String _catToJson(ItemCategory c) => c.dbValue;
ItemDateType _dtFromJson(String v) => ItemDateType.fromDb(v);
String _dtToJson(ItemDateType d) => d.dbValue;
ItemStatus _statusFromJson(String v) => ItemStatus.fromDb(v);
String _statusToJson(ItemStatus s) => s.dbValue;
DateTime _dateFromJson(String v) => DateTime.parse(v);
String _dateToJson(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
```
- [ ] Step 4: Codegen + retest
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/models/item_test.dart
```
Expected: 2 tests pass.
- [ ] Step 5: Commit
```bash
git add lib/core/models/item.dart lib/core/models/item.freezed.dart \
        lib/core/models/item.g.dart test/core/models/item_test.dart
git commit -m "feat(models): Item freezed model with JSON round-trip tests"
```

#### Task 4: Money helper (PHP formatting) — TDD

**Files:** `test/core/models/money_test.dart`, `lib/core/models/money.dart`

- [ ] Step 1: Failing tests
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/money.dart';

void main() {
  test('null minor -> empty string', () {
    expect(pesoFromMinor(null), '');
  });
  test('0 -> ₱0.00', () => expect(pesoFromMinor(0), '₱0.00'));
  test('1234 -> ₱12.34', () => expect(pesoFromMinor(1234), '₱12.34'));
  test('9999999 -> ₱99,999.99',
      () => expect(pesoFromMinor(9999999), '₱99,999.99'));
  test('parseDecimal: 12.34 -> 1234', () {
    expect(minorFromDecimal('12.34'), 1234);
  });
  test('parseDecimal: invalid -> null', () {
    expect(minorFromDecimal('abc'), null);
  });
}
```
- [ ] Step 2: Run, confirm failure
- [ ] Step 3: Implement
```dart
import 'package:intl/intl.dart';

final _phpFormat =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

String pesoFromMinor(int? minor) {
  if (minor == null) return '';
  return _phpFormat.format(minor / 100);
}

int? minorFromDecimal(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final v = double.tryParse(trimmed);
  if (v == null) return null;
  return (v * 100).round();
}
```
- [ ] Step 4: Tests pass, commit
```bash
git add lib/core/models/money.dart test/core/models/money_test.dart
git commit -m "feat(models): PHP money helpers with TDD coverage"
```

#### Task 5: Relative date label + grouping helpers — TDD

**Files:** `test/features/items/home_grouping_test.dart`, `lib/features/items/utils/date_buckets.dart`

- [ ] Step 1: Failing tests (full table — list every branch). Skeleton:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/features/items/utils/date_buckets.dart';

void main() {
  final now = DateTime.utc(2026, 5, 18);

  group('relativeDateLabel', () {
    test('-3 -> Overdue by 3 days', () {
      expect(relativeDateLabel(now.subtract(const Duration(days: 3)), now: now),
          'Overdue by 3 days');
    });
    test('0 -> Due today',
        () => expect(relativeDateLabel(now, now: now), 'Due today'));
    test('1 -> Due tomorrow', () {
      expect(relativeDateLabel(now.add(const Duration(days: 1)), now: now),
          'Due tomorrow');
    });
    // ... include each branch of the table
  });

  group('bucketize', () {
    test('groups items into 4 buckets sorted ascending', () {
      // Build a fixture list and assert.
    });
  });
}
```
- [ ] Step 2: Run, confirm failures
- [ ] Step 3: Implement `date_buckets.dart` with `enum DateBucket { overdue, thisWeek, thisMonth, later }`, `DateBucket bucketFor(DateTime target, {DateTime? now})`, `Map<DateBucket, List<Item>> bucketize(List<Item> items, {DateTime? now})`, and `String relativeDateLabel(DateTime target, {DateTime? now})`.
- [ ] Step 4: Tests pass, commit
```bash
git add lib/features/items/utils/date_buckets.dart \
        test/features/items/home_grouping_test.dart
git commit -m "feat(items): date bucketing + relative-date labels (pure logic)"
```

#### Task 6: ItemRepository interface + ItemException

**Files:** `lib/features/items/data/item_repository.dart`

- [ ] Step 1: Write
```dart
import '../../../core/models/item.dart';
import '../../../core/models/item_category.dart';
import '../../../core/models/item_date_type.dart';

abstract interface class ItemRepository {
  /// Emits the current user's active items (sorted by target_date asc).
  /// Re-emits on insert/update/delete from any source.
  Stream<List<Item>> watchActive();

  /// Throws [ItemException] on failure.
  Future<Item> add({
    required String name,
    required ItemCategory category,
    required ItemDateType dateType,
    required DateTime targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  });

  /// Patch by id. Throws [ItemException] on failure.
  Future<Item> update(
    String id, {
    String? name,
    ItemCategory? category,
    ItemDateType? dateType,
    DateTime? targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  });

  Future<Item> archive(String id);
  Future<Item> trash(String id);
  Future<Item> restore(String id);

  Future<Item> getById(String id);
}

class ItemException implements Exception {
  ItemException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ItemException($code): $message';
}
```
- [ ] Step 2: Format, analyze, commit
```bash
git add lib/features/items/data/item_repository.dart
git commit -m "feat(items): ItemRepository contract + ItemException"
```

#### Task 7: SupabaseItemRepository implementation — TDD

**Files:** `test/features/items/item_repository_test.dart` (failing), `lib/features/items/data/supabase_item_repository.dart` (implement).

This task's tests use a fake `SupabaseClient` via mocktail mocking `_client.from('items')` and its fluent chain. Pattern shown in Phase 1's `auth_controller_test.dart`. Key cases:

- `add` builds the correct payload and returns the inserted row
- `add` maps Supabase `PostgrestException(code: '42501')` (RLS denial) to `ItemException('rls', ...)`
- `update` sends only non-null fields in the patch (test omits `notes`, verifies it's NOT in the payload)
- `archive` calls update with `{status: 'archived'}`
- `trash` calls update with `{status: 'trashed', trashed_at: <now>}`
- `restore` calls update with `{status: 'active', trashed_at: null}`
- `watchActive()` filters out `archived` and `trashed` rows even if Supabase realtime emits them

Implementation outline:

```dart
class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository({sb.SupabaseClient? client, DateTime Function()? now})
      : _client = client ?? SupabaseService.client,
        _now = now ?? DateTime.now;

  final sb.SupabaseClient _client;
  final DateTime Function() _now;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw ItemException('not_signed_in', 'Not signed in');
    return id;
  }

  @override
  Stream<List<Item>> watchActive() {
    return _client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('owner_id', _uid)
        .order('target_date')
        .map((rows) => rows
            .where((r) => r['status'] == 'active')
            .map(Item.fromJson)
            .toList());
  }

  @override
  Future<Item> add({...}) async {
    final payload = {
      'owner_id': _uid,
      'name': name,
      'category': category.dbValue,
      'date_type': dateType.dbValue,
      'target_date': _dateOnly(targetDate),
      'notes': notes,
      'assignee_label': assigneeLabel,
      'amount_minor': amountMinor,
    }..removeWhere((_, v) => v == null);
    try {
      final row = await _client
          .from('items')
          .insert(payload)
          .select()
          .single();
      return Item.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'add_failed');
    }
  }

  // ... update, archive, trash, restore, getById all similar
  // archive: _patch(id, {'status': 'archived'})
  // trash:   _patch(id, {'status': 'trashed', 'trashed_at': _now().toIso8601String()})
  // restore: _patch(id, {'status': 'active', 'trashed_at': null})

  ItemException _map(sb.PostgrestException e, String fallback) {
    if (e.code == '42501') return ItemException('rls', e.message);
    return ItemException(e.code ?? fallback, e.message);
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
```

- [ ] Step 1: Write failing tests (8–10 cases)
- [ ] Step 2: Confirm fail
- [ ] Step 3: Implement
- [ ] Step 4: Tests pass; commit
```bash
git add lib/features/items/data/supabase_item_repository.dart \
        test/features/items/item_repository_test.dart
git commit -m "feat(items): Supabase repository with add/update/archive/trash/restore (TDD)"
```

#### Task 8: Item providers + form controller

**Files:** `lib/features/items/controllers/item_providers.dart`, `lib/features/items/controllers/item_form_controller.dart`

- [ ] Step 1: Write `item_providers.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../data/item_repository.dart';
import '../data/supabase_item_repository.dart';

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => SupabaseItemRepository(),
);

final itemsStreamProvider = StreamProvider<List<Item>>(
  (ref) => ref.watch(itemRepositoryProvider).watchActive(),
);

final itemByIdProvider =
    FutureProvider.family<Item, String>((ref, id) async {
  return ref.watch(itemRepositoryProvider).getById(id);
});
```
- [ ] Step 2: Write `item_form_controller.dart` — `AsyncNotifier<void>` with `submitNew(...)` and `submitEdit(itemId, ...)`. Pattern identical to Phase 1's `AuthController`.
- [ ] Step 3: Analyze + commit
```bash
git add lib/features/items/controllers/
git commit -m "feat(items): Riverpod providers + form controller"
```

#### Task 9: CategoryChip + CategoryChipSelector widgets

**Files:** `lib/features/items/ui/widgets/category_chip.dart`, `lib/features/items/ui/widgets/category_chip_selector.dart`, widget tests.

- [ ] Step 1: Implement `CategoryChip` — pill with icon + label using `ItemCategory.surface`, `ItemCategory.label`
- [ ] Step 2: Implement `CategoryChipSelector` — `Wrap` of all 9 categories with selection state callback
- [ ] Step 3: Widget test: selecting a chip emits the selected `ItemCategory` via callback; only one chip is "filled" at a time
- [ ] Step 4: Commit
```bash
git add lib/features/items/ui/widgets/category_chip*.dart \
        test/features/items/category_chip_selector_test.dart
git commit -m "feat(items): category chip widgets + selector test"
```

#### Task 10: AmountField widget — TDD

**Files:** `lib/features/items/ui/widgets/amount_field.dart`, widget test.

- [ ] Step 1: Failing test:
  - Field with `initial=null` renders empty
  - Field with `initial=1234` renders `12.34`
  - Typing `99.99` and submitting calls `onChanged(9999)`
  - Typing `abc` triggers validation error
- [ ] Step 2: Implement using `TextFormField` + `keyboardType: TextInputType.numberWithOptions(decimal: true)` + `minorFromDecimal` parser
- [ ] Step 3: Format, analyze, test, commit
```bash
git add lib/features/items/ui/widgets/amount_field.dart \
        test/features/items/amount_field_test.dart
git commit -m "feat(items): AmountField with PHP parsing + validation tests"
```

#### Task 11: Item form sheet — Add + Edit modes (widget tests first)

**Files:** `lib/features/items/ui/item_form_sheet.dart`, `test/features/items/item_form_sheet_test.dart`

- [ ] Step 1: Failing widget tests (~5 cases per the test plan in §5)
- [ ] Step 2: Implement the modal sheet with all 7 sections in §4
- [ ] Step 3: Wire to `itemFormControllerProvider`
- [ ] Step 4: Tests pass, commit
```bash
git add lib/features/items/ui/item_form_sheet.dart \
        test/features/items/item_form_sheet_test.dart
git commit -m "feat(items): Add/Edit Item modal sheet with validation TDD"
```

#### Task 12: ItemCard widget

**Files:** `lib/features/items/ui/widgets/item_card.dart`, widget test

- [ ] Step 1: Failing test — renders category label, name, relative-date label; tap calls callback
- [ ] Step 2: Implement — rounded card with category surface BG, icon, name, relative-date label; coral underline if overdue
- [ ] Step 3: Commit
```bash
git add lib/features/items/ui/widgets/item_card.dart \
        test/features/items/item_card_test.dart
git commit -m "feat(items): ItemCard widget"
```

#### Task 13: Home dashboard with real items + sections

**Files:** Modify `lib/features/home/ui/home_screen.dart`; new `lib/features/items/ui/widgets/item_card_section.dart`; new `lib/features/items/ui/widgets/empty_home_state.dart`.

- [ ] Step 1: Widget test — given `itemsStreamProvider` overridden with 4 items spanning all buckets, expect 4 section headers + 4 cards rendered
- [ ] Step 2: Widget test — empty list shows `EmptyHomeState`
- [ ] Step 3: Widget test — loading state shows skeleton; error state shows retry
- [ ] Step 4: Implement: replace existing empty card with `Consumer` of `itemsStreamProvider`, group via `bucketize`, render each non-empty bucket as `ItemCardSection`
- [ ] Step 5: Commit
```bash
git add lib/features/home/ lib/features/items/ui/widgets/item_card_section.dart \
        lib/features/items/ui/widgets/empty_home_state.dart \
        test/features/home/home_screen_test.dart
git commit -m "feat(home): real items list with date-bucketed sections"
```

#### Task 14: Wire FAB to open Add Item modal

**Files:** Modify `lib/app/shell/app_shell.dart` (replace snackbar with `showModalBottomSheet`)

- [ ] Step 1: Replace the FAB's onPressed body with:
```dart
onPressed: () => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const ItemFormSheet(),
),
```
- [ ] Step 2: Add `ItemFormSheet` import
- [ ] Step 3: Manual playwright smoke: navigate, sign in (skipped in test — use mocked container), tap +, confirm sheet opens
- [ ] Step 4: Commit
```bash
git add lib/app/shell/app_shell.dart
git commit -m "feat(shell): wire FAB to Add Item modal"
```

#### Task 15: Item Detail screen + action row

**Files:** `lib/features/items/ui/item_detail_screen.dart`, route added to `lib/app/router/app_router.dart`, action controller `lib/features/items/controllers/item_actions_controller.dart`.

- [ ] Step 1: Add route `GoRoute(path: '/item/:id', builder: (_, state) => ItemDetailScreen(id: state.pathParameters['id']!))` inside the StatefulShellBranch for `/home` (so deep nav under Home preserves bottom-nav state — or as a top-level route, decide pattern; the cleaner choice is top-level since the detail is full-screen)
- [ ] Step 2: Item Detail screen: header card (category surface BG, name, category chip), then field rows (date with relative label, notes, assignee, amount), action row at bottom
- [ ] Step 3: Wire actions to `ItemActionsController` (archive, trash, restore, edit-shortcut, mark-renewed)
- [ ] Step 4: Widget tests — action row buttons present and trigger controller methods
- [ ] Step 5: Wire `ItemCard.onTap` → `context.push('/item/${item.id}')`
- [ ] Step 6: Commit
```bash
git add lib/features/items/ui/item_detail_screen.dart \
        lib/features/items/controllers/item_actions_controller.dart \
        lib/app/router/app_router.dart \
        test/features/items/item_detail_screen_test.dart
git commit -m "feat(items): Item Detail screen with action row + actions controller"
```

#### Task 16: Soft-delete undo snackbar

**Files:** Modify `item_detail_screen.dart`, `item_card.dart` (long-press), `item_actions_controller.dart`.

- [ ] Step 1: After successful `trash(id)`, show:
```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: const Text('Item moved to Trash'),
  duration: const Duration(seconds: 5),
  action: SnackBarAction(
    label: 'Restore',
    onPressed: () => ref.read(itemActionsControllerProvider.notifier).restore(id),
  ),
));
```
- [ ] Step 2: Same pattern for `archive` with "Undo" action that calls `restore`
- [ ] Step 3: Manual smoke after this task (Playwright)
- [ ] Step 4: Commit
```bash
git add lib/features/items/
git commit -m "feat(items): undo snackbar for archive + delete"
```

#### Task 17: "Mark renewed" shortcut

**Files:** Modify `item_form_sheet.dart` to accept `focusDateOnOpen: true`; wire from Item Detail's "Mark renewed" button.

- [ ] Step 1: Add `final bool focusDateOnOpen` parameter to `ItemFormSheet`
- [ ] Step 2: In initState, if `focusDateOnOpen` is true, schedule a post-frame callback to open the date picker
- [ ] Step 3: Widget test confirms date picker is open after one pumpAndSettle
- [ ] Step 4: Commit
```bash
git add lib/features/items/ui/item_form_sheet.dart \
        lib/features/items/ui/item_detail_screen.dart
git commit -m "feat(items): Mark renewed shortcut auto-opens date picker"
```

#### Task 18: Phase 2 README updates + tag

**Files:** `README.md`, `supabase/migrations/` (already added in Tasks M1/M2).

- [ ] Step 1: Append Phase 2 status section to README (shipped / known limitations)
- [ ] Step 2: Document the new migrations in README's Supabase setup
- [ ] Step 3: Run all gates one final time
- [ ] Step 4: Playwright end-to-end smoke (instructions in §8 below)
- [ ] Step 5: Commit + tag + push
```bash
git add README.md
git commit -m "docs: Phase 2 README updates"
git tag -a v0.3-items -m "Phase 2: Items CRUD + Home dashboard"
git push
git push origin v0.3-items
```

---

## 8. Release plan — Phase 2 exit criteria

Tag `v0.3-items` ships when ALL of the following are true:

- [ ] All 17 code tasks committed, format/analyze/test green on every push
- [ ] CI green on `main` after final push
- [ ] Manual smoke (Playwright + you in Chrome):
  - [ ] Sign in
  - [ ] Add 4 items spanning all 4 buckets (overdue / this week / this month / later) with different categories and one with an amount
  - [ ] Home shows all 4 in correct sections, sorted within section
  - [ ] Open one item → Item Detail renders correctly with relative-date badge and amount in ₱
  - [ ] Edit it → save → returns to detail → fields updated
  - [ ] Mark renewed → date picker opens → pick new date → save → relative-date label updates
  - [ ] Archive one → snackbar appears with Undo → tap Undo → item reappears on Home
  - [ ] Delete one → snackbar with Restore → tap Restore → item reappears
  - [ ] Delete one and let snackbar dismiss → item disappears from Home permanently (still in DB, viewable in Supabase Table Editor as `status='trashed'`)
  - [ ] Sign out → sign back in → all surviving items reappear (persistence proof)
  - [ ] Open a second browser, sign in same account → both browsers see realtime updates within ~1 s
- [ ] Supabase Table Editor confirms: `items` rows owned only by your `auth.uid()`; no cross-user data
- [ ] `flutter build web --dart-define-from-file=.env.local` clean
- [ ] Console clean during Playwright runtime check (allow only the dev-tooling `dwds removeChild` cosmetic error)
- [ ] `v0.3-items` tag pushed

---

## 9. Cost & complexity check

### What's free in Phase 2
- Supabase free tier: every Phase 2 feature fits comfortably (DB ≪ 500 MB, realtime: 2 concurrent connections per user maxed out, well under the 200 concurrent limit)
- No new dependencies added — everything was pinned in Phase 0
- No new third-party services
- No paid AI calls
- CI: GitHub Actions free minutes; one job per push

### Potential cost growth
- **Supabase realtime** counts toward concurrent-connection quota (200/project on Free). At 1 device per user, we can support ~200 simultaneously-open apps; far above beta. Upgrade trigger: paid Pro at $25/mo at ~2k–5k DAUs.
- **Database storage** grows linearly: a typical Item row is ~300 B + small text fields; 10k items / user × 100 users = 1k items/user × 100 = still < 50 MB. Free tier covers ~1.5M items.
- **Egress**: realtime + REST traffic. Free tier = 5 GB/mo. Each item read is ~1 KB; 100 active users with 50 reads/session × 30 sessions/mo × 100 users = 150k reads = 150 MB. Well under.

### Complexity added
- **Realtime subscription** is one new failure mode (network blip → stream pauses; Supabase auto-reconnects, but UI must handle the gap gracefully via the `AsyncValue.loading` state — already covered by Riverpod's `StreamProvider`)
- **Soft-delete state** means querying `status='active'` everywhere, easy to forget. Mitigated by routing all reads through `watchActive()` in the repository — UI never queries directly
- **No Drift** means: app does not function offline. This is an explicit trade-off; offline-first becomes its own Phase 2b after beta feedback

### Risks to monitor

| Risk | Mitigation |
|---|---|
| User adds item then immediately signs out before insert returns | Repository `add()` returns the inserted row; we navigate back to Home only on success. Optimistic UI explicitly NOT used in V1. |
| Supabase realtime channel drops silently | `StreamProvider` exposes the error in `AsyncValue.error`; Home shows "Couldn't load — Retry"; tap retries by invalidating the provider. |
| User edits item on device A while device B is offline; conflict on reconnect | Phase 2 doesn't support offline writes (only reads have client-cache during session). Last-write-wins is fine for V1. Phase 2b's Drift will introduce explicit conflict handling. |
| Migration applied in wrong order (0003 RLS before 0002 table) | Migrations are number-ordered; Task M1 explicitly precedes M2 in the plan. |

---

## 10. Self-review

**Spec coverage:** §3 (categories), §4 (V1 features 2, 4, 5, 14, 16 — Trash), §8 (Items CRUD architecture), §9 (full schema, RLS), §11 (deferred — confirmed), §12 (no security regressions; we don't introduce service-role anywhere), §14 (testing matrix applied), §15 (cost model — see §9), §16 (roadmap aligned), §17 (item 1, "Settings → backup/export" still deferred).

**Placeholder scan:** no "TBD" / "implement later" / "similar to". Manual SQL tasks (M1, M2) are user actions with exact instructions.

**Type consistency:** `ItemCategory.dbValue`, `ItemDateType.dbValue`, `ItemStatus.dbValue` are the shared SQL-string identifiers across model, repository, migration, and tests. `Item.ownerId` maps to `owner_id` (Postgres convention); JSON keys verified against the migration column list. `ItemException(code, message)` mirrors the Phase 1 `AuthException` signature exactly.
