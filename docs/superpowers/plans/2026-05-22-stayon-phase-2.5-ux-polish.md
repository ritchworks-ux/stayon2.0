# StayOn Phase 2.5 — UX Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the Phase 2 feature set before opening Phase 3 (Attachments). Four targeted improvements — all pure Dart/Flutter, no schema changes, no new dependencies — that close label-accuracy gaps, add missing urgency signalling, and prevent a common UX mistake in the Add Item form. Two optional tasks add dark-mode correctness and a stub Settings screen. All tasks are TDD-first.

**Architecture:** No new layers. Changes touch `date_buckets.dart`, `item_form_sheet.dart`, `app_shell.dart`, and optionally `item_category.dart` / a new `features/settings/` feature slice. Every task is independently committable.

**Tech Stack:** No new packages. Uses only what Phase 2 pinned.

**Source spec:** [`docs/superpowers/specs/2026-05-18-stayon-mvp-design.md`](../specs/2026-05-18-stayon-mvp-design.md) §3 (copy), §7 (dark mode)
**Previous phase:** [`v0.3-items`](2026-05-18-stayon-phase-2-items.md)

---

## 1. Scope

### Core (all must ship before Phase 3)

| # | Enhancement | Files touched |
|---|---|---|
| 2.5.1 | Date-type-aware relative labels | `date_buckets.dart` · `item_card.dart` · `item_detail_screen.dart` · tests |
| 2.5.2 | Past-date warning in Add mode | `item_form_sheet.dart` · `item_form_sheet_test.dart` |
| 2.5.3 | Overdue badge on Alerts nav destination | `app_shell.dart` |

### Optional (ship if time allows; safe to defer to Phase 3 polish)

| # | Enhancement | Files touched |
|---|---|---|
| 2.5.4 | Dark-mode category surface colors | `colors.dart` · `item_category.dart` · `item_card.dart` · `item_detail_screen.dart` · `category_chip.dart` |
| 2.5.5 | Minimal Settings screen | new `features/settings/` slice · `app_router.dart` · `main.dart` · `home_header.dart` |

### Out of scope
Swipe-to-dismiss (`Dismissible`) · archive/trash list screens · search · attachments · reminders — all deferred to their target phases.

---

## 2. Technical notes

### 2.5.1 — `relativeDateLabel` backwards-compatible extension

Add an optional `dateType` parameter (default `null`). When `null`, the function falls back to the existing `"Due …"` copy so all call-sites that do not pass `dateType` keep working. When provided, the verb (`Due` / `Expires` / `Renews`) is driven by `ItemDateType`. Overdue copy (`"Overdue by N days"`) is type-agnostic — an item is overdue regardless of its date type.

Verb map:
```
ItemDateType.due      → "Due"
ItemDateType.expires  → "Expires"
ItemDateType.renews   → "Renews"
null                  → "Due"  (backward-compat default)
```

Both `ItemCard` and `ItemDetailScreen` already have access to `item.dateType` — they just need to pass it through.

All existing `home_grouping_test.dart` cases use `ItemDateType.expires`; they currently assert `"Due in X days"` — those assertions must be updated to `"Expires in X days"` etc. as part of this task (TDD: update test first, watch it fail, then fix production code).

### 2.5.2 — Past-date warning

Day-level comparison only (no time-of-day). A date is "in the past" if `targetDate` is strictly before today at midnight. Shown only in Add mode (`!_isEdit`); Edit mode intentionally omits it because an existing item might legitimately have a past date that the user hasn't renewed yet.

Visual: a small row with `Icons.info_outline` in `AppColors.coral` and body-medium text in `AppColors.coral`, rendered immediately below the date picker container. Uses `AnimatedSwitcher` (cross-fade, 200 ms) so it appears/disappears smoothly when the picker value changes.

### 2.5.3 — Badge on Alerts nav destination

`AppShell` is currently a `StatelessWidget`. Change to `ConsumerWidget` so it can watch `itemsProvider`. Derive `overdueCount` from the loaded value. Use Flutter's built-in `Badge.count` widget wrapping both the default and selected icons of the Alerts destination. `isLabelVisible: overdueCount > 0` hides the badge when the count is zero.

### 2.5.4 — Dark-mode surfaces (optional)

Add a `darkSurface` field to each `ItemCategory` enum value (parallel to `surface`). Add the nine dark tokens to `AppColors`. Replace every direct `item.category.surface` usage with `item.category.surfaceFor(context)` — a new instance method that reads `Theme.of(context).brightness` and returns the appropriate token.

### 2.5.5 — Settings screen (optional)

Single route `/settings` (full-screen, no bottom nav, same pattern as `/item/:id`). A `themeModeProvider` (`StateProvider<ThemeMode>`) lives in `features/settings/controllers/`. Wire `MaterialApp.themeMode` in `main.dart` to watch it. Three sections: account info (avatar + email, read-only), theme toggle (segmented: Light / System / Dark), sign-out. Enable the previously disabled `"Settings"` menu entry in `HomeHeader`.

---

## 3. Tasks

---

### Task 2.5.1 — Date-type-aware relative labels (TDD)

**Files:**
- `lib/features/items/utils/date_buckets.dart` ← modify
- `lib/features/items/ui/widgets/item_card.dart` ← modify
- `lib/features/items/ui/item_detail_screen.dart` ← modify
- `test/features/items/home_grouping_test.dart` ← update assertions first
- `test/features/items/item_card_test.dart` ← update assertion

---

#### Step 1 — Update tests to assert the new copy (they will fail now)

In `test/features/items/home_grouping_test.dart`, update every `relativeDateLabel` assertion that uses `"Due …"` or `"Overdue …"` copy to reflect the correct verb for the item's `dateType`. The stub helper `_item` uses `ItemDateType.expires`, so:

- `"Due today"` → `"Expires today"`
- `"Due tomorrow"` → `"Expires tomorrow"`
- `"Due in 3 days"` → `"Expires in 3 days"`
- …and so on for every test case in the `group('relativeDateLabel', …)` block.
- `"Overdue by N days"` stays unchanged (type-agnostic).

Add three new tests below the existing group to cover all three verbs explicitly:

```dart
group('relativeDateLabel — verb by dateType', () {
  final now = _d(2026, 5, 18);

  test('expires + future → "Expires in N days"', () {
    expect(
      relativeDateLabel(
        now.add(const Duration(days: 5)),
        now: now,
        dateType: ItemDateType.expires,
      ),
      'Expires in 5 days',
    );
  });

  test('renews + future → "Renews in N days"', () {
    expect(
      relativeDateLabel(
        now.add(const Duration(days: 5)),
        now: now,
        dateType: ItemDateType.renews,
      ),
      'Renews in 5 days',
    );
  });

  test('due + future → "Due in N days"', () {
    expect(
      relativeDateLabel(
        now.add(const Duration(days: 5)),
        now: now,
        dateType: ItemDateType.due,
      ),
      'Due in 5 days',
    );
  });

  test('null dateType → "Due in N days" (backward compat)', () {
    expect(
      relativeDateLabel(now.add(const Duration(days: 5)), now: now),
      'Due in 5 days',
    );
  });

  test('overdue is always "Overdue by N days" regardless of type', () {
    for (final dt in ItemDateType.values) {
      expect(
        relativeDateLabel(
          now.subtract(const Duration(days: 3)),
          now: now,
          dateType: dt,
        ),
        'Overdue by 3 days',
      );
    }
  });

  test('expires + today → "Expires today"', () {
    expect(
      relativeDateLabel(now, now: now, dateType: ItemDateType.expires),
      'Expires today',
    );
  });

  test('renews + tomorrow → "Renews tomorrow"', () {
    expect(
      relativeDateLabel(
        now.add(const Duration(days: 1)),
        now: now,
        dateType: ItemDateType.renews,
      ),
      'Renews tomorrow',
    );
  });
});
```

In `test/features/items/item_card_test.dart`, update the test `'renders name, uppercased category label, and relative date'` — the stub uses `ItemDateType.expires` and `targetDate: _d(2026, 5, 21)` (3 days out from `now = _d(2026, 5, 18)`), so update the assertion:

```dart
// before:
expect(find.text('Due in 3 days'), findsOneWidget);
// after:
expect(find.text('Expires in 3 days'), findsOneWidget);
```

Run tests — they should **fail** on the label assertions:

```bash
flutter test test/features/items/home_grouping_test.dart test/features/items/item_card_test.dart
```

Expected: multiple failures on `"Due in X days"` → `"Expires in X days"` mismatches.

---

#### Step 2 — Update `relativeDateLabel` in `date_buckets.dart`

Replace the existing `relativeDateLabel` function with:

```dart
/// Human-friendly relative-date string. The verb is driven by [dateType]
/// so cards read "Expires in 3 days", "Renews tomorrow", "Due today" etc.
///
/// When [dateType] is null the function falls back to "Due …" so
/// existing call-sites that omit the parameter keep working.
///
/// Overdue copy is type-agnostic ("Overdue by N days") — an item is
/// overdue regardless of what its date was supposed to mean.
String relativeDateLabel(
  DateTime target, {
  DateTime? now,
  ItemDateType? dateType,
}) {
  final delta = _daysBetween(target, now ?? DateTime.now());
  final verb = _verb(dateType);

  if (delta < 0) {
    final n = -delta;
    return 'Overdue by $n day${n == 1 ? '' : 's'}';
  }
  if (delta == 0) return '$verb today';
  if (delta == 1) return '$verb tomorrow';
  if (delta <= 30) return '$verb in $delta days';
  if (delta < 365) {
    final months = (delta / 30).round();
    return '$verb in $months month${months == 1 ? '' : 's'}';
  }
  return '$verb in over a year';
}

String _verb(ItemDateType? dt) {
  switch (dt) {
    case ItemDateType.expires:
      return 'Expires';
    case ItemDateType.renews:
      return 'Renews';
    case ItemDateType.due:
    case null:
      return 'Due';
  }
}
```

Add the missing import at the top of `date_buckets.dart`:

```dart
import '../../../core/models/item_date_type.dart';
```

Run tests:

```bash
flutter test test/features/items/home_grouping_test.dart
```

Expected: all `relativeDateLabel` tests pass. `bucketFor` and `bucketize` tests unaffected.

---

#### Step 3 — Pass `dateType` in `ItemCard`

In `lib/features/items/ui/widgets/item_card.dart`, update the `relativeDateLabel` call:

```dart
// before:
final rel = relativeDateLabel(item.targetDate, now: now);

// after:
final rel = relativeDateLabel(item.targetDate, now: now, dateType: item.dateType);
```

Run card tests:

```bash
flutter test test/features/items/item_card_test.dart
```

Expected: all pass.

---

#### Step 4 — Pass `dateType` in `ItemDetailScreen`

In `lib/features/items/ui/item_detail_screen.dart`, inside `_DetailBody.build`:

```dart
// before:
final rel = relativeDateLabel(item.targetDate);

// after:
final rel = relativeDateLabel(item.targetDate, dateType: item.dateType);
```

---

#### Step 5 — Full test suite + analyzer

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: no issues, all tests pass.

---

#### Step 6 — Commit

```bash
git add lib/features/items/utils/date_buckets.dart \
        lib/features/items/ui/widgets/item_card.dart \
        lib/features/items/ui/item_detail_screen.dart \
        test/features/items/home_grouping_test.dart \
        test/features/items/item_card_test.dart
git commit -m "feat(items): date-type-aware relative labels (Expires/Renews/Due)"
```

---

### Task 2.5.2 — Past-date warning in Add mode (TDD)

**Files:**
- `test/features/items/item_form_sheet_test.dart` ← add tests first
- `lib/features/items/ui/item_form_sheet.dart` ← implement

---

#### Step 1 — Write failing tests

Open `test/features/items/item_form_sheet_test.dart` and add a new group at the end of `main()`:

```dart
group('past-date warning', () {
  // Re-use the mock repository and provider override already defined
  // at the top of the file — no additional setup needed.

  testWidgets('shows warning when Add mode picks a past date', (
    tester,
  ) async {
    await tester.pumpWidget(/* existing helper that wraps ItemFormSheet() */);

    // Confirm no warning yet (default date is today or future).
    expect(find.byKey(const Key('past_date_warning')), findsNothing);

    // Simulate the form having a past date set. We can't drive the
    // real DatePicker in unit tests, so we expose the warning via a
    // ValueKey and test its presence after setting state directly.
    // (See implementation note in Step 2.)
  });

  testWidgets('warning absent in Edit mode even with past target date', (
    tester,
  ) async {
    final pastItem = _stubItem().copyWith(
      targetDate: DateTime.now().subtract(const Duration(days: 10)),
    );
    await tester.pumpWidget(
      /* existing helper that wraps ItemFormSheet(existing: pastItem) */,
    );

    expect(find.byKey(const Key('past_date_warning')), findsNothing);
  });
});
```

> **Implementation note:** the `DatePicker` dialog cannot be triggered in headless tests. The warning widget is keyed with `Key('past_date_warning')` so widget tests can check presence/absence after programmatically mutating `_targetDate` via the `@visibleForTesting` test-backdoor described in Step 2. The real end-to-end behaviour is covered by the manual test matrix.

Run — tests fail (key not found):

```bash
flutter test test/features/items/item_form_sheet_test.dart
```

---

#### Step 2 — Implement the warning in `ItemFormSheet`

In `lib/features/items/ui/item_form_sheet.dart`:

**a)** Add a helper getter to `_ItemFormSheetState`:

```dart
/// True when the selected date is strictly before today (day-level) and
/// we are in Add mode. Used to show the overdue hint.
bool get _targetIsInPast {
  if (_isEdit) return false;
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final targetMidnight = DateTime(
    _targetDate.year,
    _targetDate.month,
    _targetDate.day,
  );
  return targetMidnight.isBefore(todayMidnight);
}
```

**b)** Insert the warning widget immediately after the date-picker `InkWell` container, still inside the `Column` in `DraggableScrollableSheet.builder`:

```dart
// … date picker InkWell …
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: _targetIsInPast
      ? Padding(
          key: const Key('past_date_warning'),
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.coral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This date is in the past — item will appear as Overdue.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.coral,
                  ),
                ),
              ),
            ],
          ),
        )
      : const SizedBox.shrink(),
),
```

> **`AnimatedSwitcher` note:** The `child` swap requires a different `key` on each child — `Key('past_date_warning')` vs the implicit key on `SizedBox.shrink()` — for the cross-fade to trigger. The `Key` on the `Padding` satisfies this.

Run tests:

```bash
flutter test test/features/items/item_form_sheet_test.dart
```

Expected: all pass, including the new group.

---

#### Step 3 — Analyzer + full suite

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: clean.

---

#### Step 4 — Commit

```bash
git add lib/features/items/ui/item_form_sheet.dart \
        test/features/items/item_form_sheet_test.dart
git commit -m "feat(items): past-date warning in Add Item form"
```

---

### Task 2.5.3 — Overdue badge on Alerts nav destination

**Files:**
- `lib/app/shell/app_shell.dart` ← modify

> No new tests needed — badge count is derived directly from `itemsProvider` which is already unit-tested. The widget integration is verified in the manual test matrix.

---

#### Step 1 — Convert `AppShell` to `ConsumerWidget`

Replace the class declaration and add the overdue count derivation:

```dart
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
```

Add `flutter_riverpod` import if not already present:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/items/controllers/item_providers.dart';
import '../../features/items/utils/date_buckets.dart';
```

---

#### Step 2 — Derive `overdueCount` in `build`

Update `build` signature and add count derivation at the top:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Silently reads itemsProvider; null when still loading or errored.
  // Badge only appears when we have a confirmed non-zero overdue count.
  final itemsAsync = ref.watch(itemsProvider);
  final now = DateTime.now();
  final overdueCount = itemsAsync.valueOrNull
          ?.where(
            (item) => bucketFor(item.targetDate, now: now) == DateBucket.overdue,
          )
          .length ??
      0;
```

---

#### Step 3 — Replace the static `_destinations` list with a builder method

Remove the `static const _destinations` list and replace it with a method that takes `overdueCount`:

```dart
List<NavigationDestination> _destinations(int overdueCount) => [
  const NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  const NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: 'Calendar',
  ),
  NavigationDestination(
    icon: Badge.count(
      count: overdueCount,
      isLabelVisible: overdueCount > 0,
      child: const Icon(Icons.notifications_outlined),
    ),
    selectedIcon: Badge.count(
      count: overdueCount,
      isLabelVisible: overdueCount > 0,
      child: const Icon(Icons.notifications),
    ),
    label: 'Alerts',
  ),
  const NavigationDestination(
    icon: Icon(Icons.people_outlined),
    selectedIcon: Icon(Icons.people),
    label: 'Family',
  ),
];
```

Update the `NavigationBar` to call the method:

```dart
NavigationBar(
  selectedIndex: navigationShell.currentIndex,
  destinations: _destinations(overdueCount),
  onDestinationSelected: (i) => navigationShell.goBranch(
    i,
    initialLocation: i == navigationShell.currentIndex,
  ),
),
```

---

#### Step 4 — Analyzer + full suite

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: clean.

---

#### Step 5 — Commit

```bash
git add lib/app/shell/app_shell.dart
git commit -m "feat(shell): overdue badge count on Alerts nav destination"
```

---

### Task 2.5.4 — Dark-mode category surface colors (optional)

**Files:**
- `lib/app/theme/colors.dart` ← add dark tokens
- `lib/core/models/item_category.dart` ← add `darkSurface` field + `surfaceFor` method
- `lib/features/items/ui/widgets/item_card.dart` ← use `surfaceFor`
- `lib/features/items/ui/item_detail_screen.dart` ← use `surfaceFor`
- `lib/features/items/ui/widgets/category_chip.dart` ← use `surfaceFor`

---

#### Step 1 — Add dark surface tokens to `AppColors`

In `lib/app/theme/colors.dart`, append below the existing `// Category surfaces` block:

```dart
// Category surfaces — dark mode (deeper, richer variants)
static const catMedicineDark    = Color(0xFF5C2D22);
static const catGroceryDark     = Color(0xFF5C3F10);
static const catDocumentDark    = Color(0xFF1A2E55);
static const catSubscriptionDark = Color(0xFF163326);
static const catWarrantyDark    = Color(0xFF3B1F5C);
static const catBillDark        = Color(0xFF5C1A2A);
static const catInsuranceDark   = Color(0xFF1A2E55);
static const catOtherDark       = Color(0xFF2A2A2A);
```

---

#### Step 2 — Add `darkSurface` and `surfaceFor` to `ItemCategory`

Update the enum in `lib/core/models/item_category.dart`:

```dart
enum ItemCategory {
  warranty(
    'warranty', 'Warranty',
    AppColors.catWarranty, AppColors.catWarrantyDark,
    Icons.shield_outlined,
  ),
  subscription(
    'subscription', 'Subscription',
    AppColors.catSubscription, AppColors.catSubscriptionDark,
    Icons.subscriptions_outlined,
  ),
  idLicense(
    'id_license', 'ID / License',
    AppColors.catDocument, AppColors.catDocumentDark,
    Icons.badge_outlined,
  ),
  insurance(
    'insurance', 'Insurance',
    AppColors.catInsurance, AppColors.catInsuranceDark,
    Icons.health_and_safety_outlined,
  ),
  medicine(
    'medicine', 'Medicine',
    AppColors.catMedicine, AppColors.catMedicineDark,
    Icons.medication_outlined,
  ),
  grocery(
    'grocery', 'Grocery',
    AppColors.catGrocery, AppColors.catGroceryDark,
    Icons.local_grocery_store_outlined,
  ),
  bill(
    'bill', 'Bill',
    AppColors.catBill, AppColors.catBillDark,
    Icons.receipt_long_outlined,
  ),
  document(
    'document', 'Document',
    AppColors.catDocument, AppColors.catDocumentDark,
    Icons.description_outlined,
  ),
  other(
    'other', 'Other',
    AppColors.catOther, AppColors.catOtherDark,
    Icons.label_outline,
  );

  const ItemCategory(
    this.dbValue, this.label, this.surface, this.darkSurface, this.icon,
  );

  final String dbValue;
  final String label;
  final Color surface;
  final Color darkSurface;
  final IconData icon;

  /// Returns [surface] in light mode, [darkSurface] in dark mode.
  Color surfaceFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static ItemCategory fromDb(String value) => ItemCategory.values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => ItemCategory.other,
  );
}
```

---

#### Step 3 — Update `ItemCard` to use `surfaceFor`

In `lib/features/items/ui/widgets/item_card.dart`, replace:

```dart
// before
color: item.category.surface,

// after
color: item.category.surfaceFor(context),
```

---

#### Step 4 — Update `ItemDetailScreen` to use `surfaceFor`

In `lib/features/items/ui/item_detail_screen.dart`, in `_DetailBody.build`, replace:

```dart
// before
color: item.category.surface,

// after
color: item.category.surfaceFor(context),
```

---

#### Step 5 — Update `CategoryChip`

In `lib/features/items/ui/widgets/category_chip.dart`, replace any direct `category.surface` reference with `category.surfaceFor(context)`.

---

#### Step 6 — Analyzer + full suite

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: clean. (The `item_card_test.dart` uses `MaterialApp` which defaults to light brightness — no assertion changes needed.)

---

#### Step 7 — Commit

```bash
git add lib/app/theme/colors.dart \
        lib/core/models/item_category.dart \
        lib/features/items/ui/widgets/item_card.dart \
        lib/features/items/ui/item_detail_screen.dart \
        lib/features/items/ui/widgets/category_chip.dart
git commit -m "feat(theme): dark-mode category surface colors"
```

---

### Task 2.5.5 — Minimal Settings screen (optional)

**Files:**
- new `lib/features/settings/controllers/theme_controller.dart`
- new `lib/features/settings/ui/settings_screen.dart`
- `lib/app/router/app_router.dart` ← add `/settings` route
- `lib/main.dart` ← wire `themeModeProvider`
- `lib/features/home/ui/widgets/home_header.dart` ← enable Settings menu item

---

#### Step 1 — `themeModeProvider`

Create `lib/features/settings/controllers/theme_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the user's theme preference for this session.
/// Phase 6 will persist to `flutter_secure_storage`.
final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
);
```

---

#### Step 2 — `SettingsScreen`

Create `lib/features/settings/ui/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/auth_providers.dart';
import '../controllers/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    final email = user?.email ?? '';
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : email.split('@').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── Account ──────────────────────────────────────────
          Text('Account', style: t.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.forest,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'NunitoSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.titleMedium),
                    Text(
                      email,
                      style: t.bodyMedium?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/auth/sign-in');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const Divider(height: 40),

          // ── Appearance ───────────────────────────────────────
          Text('Appearance', style: t.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).state = s.first,
          ),
          const Divider(height: 40),

          // ── Coming soon ──────────────────────────────────────
          Text(
            'More settings — notifications, export, and account deletion — '
            'arrive in Phase 6.',
            style: t.bodyMedium?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

#### Step 3 — Add `/settings` route

In `lib/app/router/app_router.dart`, add the settings route alongside the `/item/:id` route (before the `StatefulShellRoute`):

```dart
import '../../features/settings/ui/settings_screen.dart';

// … inside the routes list …

GoRoute(
  path: '/settings',
  builder: (_, _) => const SettingsScreen(),
),
```

---

#### Step 4 — Wire `themeModeProvider` in `main.dart`

Convert `StayOnApp` to a `ConsumerWidget` and watch the provider:

```dart
class StayOnApp extends ConsumerWidget {
  const StayOnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'StayOn',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

---

#### Step 5 — Enable Settings menu item in `HomeHeader`

In `lib/features/home/ui/widgets/home_header.dart`, update the `PopupMenuButton` `onSelected` callback and enable the Settings item:

```dart
PopupMenuButton<String>(
  tooltip: 'Account',
  onSelected: (value) {
    if (value == 'signout') onSignOut();
    if (value == 'settings') context.push('/settings');
  },
  itemBuilder: (_) => const [
    PopupMenuItem<String>(
      value: 'settings',
      child: Text('Settings'),          // was: 'Settings (coming soon)', enabled: false
    ),
    PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
  ],
  child: /* … */,
),
```

> **Note:** `HomeHeader` needs a `BuildContext` for `context.push`. It's a `ConsumerWidget` build method so `context` is already available.

---

#### Step 6 — Analyzer + full suite

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: clean.

---

#### Step 7 — Commit

```bash
git add lib/features/settings/ \
        lib/app/router/app_router.dart \
        lib/main.dart \
        lib/features/home/ui/widgets/home_header.dart
git commit -m "feat(settings): minimal settings screen — theme toggle + sign out"
```

---

## 4. Phase 2.5 Exit Gate

Run all checks green before tagging `v0.4-ux-polish`:

- [ ] `dart format --set-exit-if-changed .` → clean
- [ ] `flutter analyze --fatal-infos` → `No issues found!`
- [ ] `flutter test` → all pass (no regressions)
- [ ] Manual smoke — Add Item form: pick a past date → overdue hint appears; pick today → hint disappears
- [ ] Manual smoke — Item cards show "Expires/Renews/Due in …" matching each item's `dateType`
- [ ] Manual smoke — Alerts nav badge shows correct overdue count; disappears when count is zero
- [ ] *(optional)* Manual smoke — dark mode: item cards and chips use deeper surface colors
- [ ] *(optional)* Manual smoke — Settings: theme toggle switches light/dark/system; sign out navigates to auth

```bash
git tag -a v0.4-ux-polish -m "Phase 2.5: UX polish — date-type labels, past-date warning, overdue badge"
git push --tags
```

---

## 5. Phase 3 Readiness Audit

> Confirm all boxes below before writing the Phase 3 plan.

### Dependencies (already in `pubspec.yaml`)

| Package | Why needed in Phase 3 | Status |
|---|---|---|
| `image_picker` ^1.1.2 | Pick photos from camera + gallery | ✅ pinned |
| `file_picker` ^8.0.6 | Pick arbitrary files (PDF, docs) | ✅ pinned |
| `flutter_image_compress` ^2.3.0 | Compress picked images before upload | ✅ pinned |
| `cached_network_image` ^3.4.0 | Thumbnail rendering from Supabase Storage URLs | ✅ pinned |
| `pdfx` ^2.6.0 | In-app PDF viewer | ✅ pinned (`pdfx:install_web` run in Phase 1) |

**Result: ✅ No new dependencies needed for Phase 3.**

### Supabase Storage

| Item | Status |
|---|---|
| `attachments` bucket created in Supabase dashboard | ⬜ Must do before Phase 3 coding starts |
| Storage RLS: authenticated users can upload/read/delete their own files | ⬜ Migration `0004_storage.sql` to write in Phase 3 |
| `items` foreign key exists for `item_id` on `attachments` table | ⬜ Migration `0004_storage.sql` to write in Phase 3 |

### Code quality gates

| Check | Status |
|---|---|
| `dart format --set-exit-if-changed .` | ⬜ Run at Phase 2.5 exit gate |
| `flutter analyze --fatal-infos` | ⬜ Run at Phase 2.5 exit gate |
| `flutter test` (all pass) | ⬜ Run at Phase 2.5 exit gate |
| No `TODO` / `FIXME` in Phase 2 code | ⬜ Quick grep before Phase 3 |

### Architectural readiness

| Item | Status |
|---|---|
| `ItemRepository` interface is clean and stable — Phase 3 adds a separate `AttachmentRepository` without touching it | ✅ |
| `ItemDetailScreen` has a clear action area below the fields — Phase 3 adds an attachment gallery above the action row | ✅ |
| `SupabaseService.client` singleton is accessible from any new repository without ceremony | ✅ |
| Drift local cache deliberately deferred — Phase 3 does NOT need to introduce it for attachments (on-demand download to docs dir is sufficient for V1) | ✅ per Phase 2 arch decision |

### One open item to resolve before Phase 3

> **`items_data_source.dart` Dart 3.7 null-shorthand syntax** — `SupabaseItemRepository.add()` uses `'notes': ?notes` (Dart 3.7+ experimental null-aware map entry syntax). Confirm this compiles and passes CI on the pinned SDK (`^3.11.5`). If it does, no action needed; if it doesn't, replace with `if (notes != null) 'notes': notes` guards before Phase 3. Add a comment in Phase 3's plan to either normalize this syntax across the codebase or file a tech-debt ticket.

---

*Next phase plan:* `docs/superpowers/plans/2026-05-22-stayon-phase-3-attachments.md` — write this doc at the start of Phase 3.
