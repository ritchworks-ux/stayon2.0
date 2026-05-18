# StayOn MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship StayOn V1 to App Store and Google Play in ~8 weeks — a free, cloud-first Flutter app that helps users (Philippines first, globally usable) track items with expiration, renewal, or due dates, with attachments, local reminders, OCR-lite pre-fill, signed share links, and a 30-day Trash.

**Architecture:** Single Flutter 3.x codebase (iOS + Android). Supabase backend (Postgres + Auth + Storage + RLS + pg_cron). Riverpod state, go_router routing, Drift local cache, `flutter_local_notifications` for reminders, `google_mlkit_text_recognition` for on-device OCR. No server we maintain.

**Tech Stack:** Flutter 3.x · Dart 3 · Material 3 · Nunito Sans · Riverpod · go_router · freezed · json_serializable · supabase_flutter · drift · flutter_local_notifications · google_mlkit_text_recognition · flutter_secure_storage · intl · sentry_flutter.

**Source spec:** [`docs/superpowers/specs/2026-05-18-stayon-mvp-design.md`](../specs/2026-05-18-stayon-mvp-design.md)

---

## A. MVP Scope Summary

### V1 (ship in ~8 weeks)
Auth (email + Google + Apple) · Items CRUD with 9 preset categories · multi-file attachments · local push reminders · OCR-lite single-doc pre-fill · per-item signed share links · Family tab (People & Shares — no real invites) · Calendar tab · Alerts tab · Search · Soft-delete Trash (30-day purge) · Settings (defaults, theme, export, delete account) · Manual JSON+zip export.

### V1.5 (first patch releases, post-launch)
Insights screen (spend by category, expiry trends — `amount_minor` already captured in V1) · barcode scan · recurring auto-renewal · opt-in PostHog analytics.

### V2 (next major)
Multi-item grocery receipt OCR + shelf-life suggestions (LLM-backed, premium gate) · custom categories · real shared households (invites + roles + realtime) · calendar sync (Google/iOS) · widgets · CSV import · IAP / Pro tier · Tagalog UI.

### Delayed / V3
Email-forwarding inbox · Apple Watch · Tags · Custom themes · Location reminders · Web app.

---

## B. Technical Architecture (locked)

- **App:** Flutter 3.x · Dart 3 · Material 3 · Nunito Sans only · light + dark themes · tokens per spec §3.
- **State:** `flutter_riverpod` — controllers in `features/<x>/controllers/`, no business logic in widgets.
- **Routing:** `go_router` with typed routes + deep links for share URLs.
- **Layering:** UI → Controller (Riverpod) → Repository → Service (Supabase / local).
- **Models:** `freezed` + `json_serializable`.
- **Backend:** Supabase (region `ap-southeast-1`) — Postgres, Auth, Storage, Edge Functions for signed-URL generation, `pg_cron` for Trash purge.
- **Local cache:** `drift` mirrors `items` + `reminders` for offline read and notification scheduling. Attachments cached on-demand to app docs dir.
- **Secrets:** Supabase URL + anon key bundled via `--dart-define` (anon key is safe with RLS); session tokens in `flutter_secure_storage`.

### Folder layout
```
lib/
  main.dart
  app/                    // theme, router, app shell, scaffolding
    theme/
      colors.dart
      typography.dart
      app_theme.dart
    router/
      app_router.dart
    shell/
      app_shell.dart
  core/
    services/
      supabase_service.dart
      notification_service.dart
      file_service.dart
      ocr_service.dart
    models/               // shared freezed models
    utils/
  features/
    auth/
      data/
      controllers/
      ui/
    items/
    attachments/
    reminders/
    sharing/
    family/
    ocr/
    trash/
    calendar/
    alerts/
    search/
    settings/
test/
integration_test/
supabase/
  migrations/
  functions/
```

### Key dependencies (pin in Phase 0)
| Package | Why |
|---|---|
| `flutter_riverpod` ^2.5 | State |
| `go_router` ^14 | Routing |
| `supabase_flutter` ^2.5 | Backend |
| `freezed_annotation` + `freezed` + `json_serializable` + `build_runner` | Models |
| `drift` ^2.18 + `drift_dev` + `sqlite3_flutter_libs` | Local DB |
| `flutter_local_notifications` ^17 + `timezone` ^0.9 | Reminders |
| `flutter_secure_storage` ^9 | Session tokens |
| `image_picker` ^1, `file_picker` ^8, `flutter_image_compress` ^2 | Attachments |
| `cached_network_image` ^3 | Thumbnails |
| `pdfx` ^2 | PDF viewer |
| `google_mlkit_text_recognition` ^0.13 | OCR-lite |
| `intl` ^0.19 | Locale dates/currency |
| `sentry_flutter` ^8 | Crash reporting |
| Dev: `flutter_lints` ^4, `mocktail` ^1, `integration_test` |  |

---

## C. Database / Schema Plan

All tables, RLS policies, and `pg_cron` purge job are defined in spec §9. They land as a single initial migration `supabase/migrations/0001_init.sql` in Phase 2.

Migrations checklist:
- `0001_init.sql` — tables + check constraints + indexes (Phase 2)
- `0002_rls.sql` — RLS policies (Phase 2)
- `0003_storage.sql` — `attachments` bucket + storage policies (Phase 3)
- `0004_share_token_function.sql` — Edge Function helper for signed-URL share reads (Phase 6)
- `0005_pg_cron_purge.sql` — daily purge of trashed items >30d (Phase 6)

Indexes from day one:
- `items (owner_id, target_date)` — dashboard sort
- `items (owner_id, status)` — list filters
- `share_links (token)` unique
- `attachments (item_id)`

---

## D. UI Screen Plan (build order)

Built in this order; each phase wires its screens end-to-end before the next:

| Phase | Screens |
|---|---|
| 1 | Splash · Auth (sign in/up tabs) · Onboarding carousel (3) · App shell + bottom nav · empty Home |
| 2 | Home dashboard (hero-matched) · Add/Edit Item modal · Item Detail |
| 3 | Attachment picker UI · Attachment Viewer (image + PDF) |
| 4 | Settings → Default reminders · per-item reminder editor |
| 5 | OCR scan flow · Search tab · Calendar tab · Alerts tab |
| 6 | Family tab (People & Shares) · Share link sheet · Trash · Settings (Account, Theme, Backup, Delete account) · About/Privacy/ToS |
| 7 | Polish: empty states, dark mode pass, accessibility, splash/icons |

---

## E. Reminder & Notification Plan

- `NotificationService` wraps `flutter_local_notifications` + `timezone` (init with `tz.local`, default `Asia/Manila`).
- On item create/update, controller computes for each `reminder.offset_days`: `fire_at = target_date - offset_days @ 09:00 device_tz`. Cancels prior `local_notification_id`s, schedules new ones, persists IDs back to DB.
- On app launch, `reconcileReminders()`: pull active items from Drift, diff against `pendingNotificationRequests()`, fix drift.
- Default offsets `[7, 1]`; user-editable globally in Settings and per-item.
- Permission denial → in-app banner with deep link to OS settings.
- Past `target_date` → don't schedule, render "Overdue" badge.

---

## F. OCR-Lite Plan

- `OcrService` wraps `google_mlkit_text_recognition` (on-device, no API cost).
- Flow: camera → `TextRecognizer.processImage()` → `OcrExtractor` heuristic returns `{name?, date?, category?}`:
  - `name`: longest line in top 25% of image with stop-word filter.
  - `date`: regex match `MM/DD/YYYY | DD MMM YYYY | MMM YYYY` etc.; if multiple, pick latest future date.
  - `category`: keyword map (`{"PhilHealth": id_license, "Meralco": bill, ...}`) — PH-tuned seed list, English-extendable.
- Pre-filled fields appear in the standard Add Item form with a small "Pre-filled from photo" hint. User always confirms before save.
- No multi-item receipt parsing in V1.

---

## G. Cost-Conscious Tool Choices

| Need | Choice | Cost |
|---|---|---|
| Backend | Supabase Free | $0 |
| Push | `flutter_local_notifications` (local only) | $0 |
| OCR | Google ML Kit on-device | $0 |
| Crash | Sentry Developer | $0 |
| CI | GitHub Actions Free + Codemagic Free | $0 |
| Design | Figma Free | $0 |
| Apple Developer | required | $99 / yr |
| Play Developer | one-time | $25 |
| Domain | `getstayon.app` | ~$12 / yr |
| **First-year total** | | **~$136** |

Upgrade Supabase Pro ($25/mo) only when usage requires. Avoid Firebase (Storage cost), Auth0, OneSignal Pro, Crashlytics Blaze.

---

## H. Testing Checklist (applied per phase)

- **Unit:** repositories (mocktail-mocked Supabase + Drift), reminder offset math, date/timezone helpers, OCR extractor, signed-URL helper, soft-delete purge logic.
- **Widget:** Add Item form validation, Home empty/loaded/error states, Item Detail action row, Trash restore.
- **Integration (`integration_test`):** sign-up → add item → DB read → notification scheduled; delete → Trash → restore → fake-clock purge.
- **Manual matrix:** iOS 16/17/18 · Android 10/13/14 · light + dark · small + large phones · airplane mode (queued upload).
- **Pre-launch:** notifications fire when locked / backgrounded / killed; permission-denial paths; share link opens in mobile browser for non-installed recipients; account deletion cascades.

Per-phase exit gates: `dart format --set-exit-if-changed .` · `flutter analyze --fatal-infos` · `flutter test`.

---

## I. Build Phases (master timeline)

Each phase ends with a tag (`v0.1`, `v0.2`, …) and produces a runnable build.

| Phase | Week | Output | Status |
|---|---|---|---|
| **0. Scaffold** | 0 | Flutter project initialised, deps pinned, theme + tokens, lints, CI, this plan extended for Phase 1 | **Detailed below** |
| **1. Auth + App shell** | 1 | Supabase configured · Sign in / Sign up working · bottom nav skeleton · empty Home | Plan written start of phase |
| **2. Items CRUD** | 2 | Tables + RLS · Drift cache · Add/Edit/Detail · Home dashboard list | " |
| **3. Attachments** | 3 | Pick · compress · upload · gallery + PDF viewer · delete | " |
| **4. Reminders** | 4 | Local notifications scheduled / cancelled / reconciled · per-item editor · defaults UI | " |
| **5. OCR-lite + Search + Calendar + Alerts** | 5 | OCR scan flow · Search tab · Calendar month view · Alerts tabs | " |
| **6. Family tab + Sharing + Trash + Settings polish** | 6 | People & Shares · signed share links · Trash w/ 30d purge · backup export · delete account | " |
| **7. Polish + Beta** | 7 | Onboarding · empty states · a11y · icons · splash · TestFlight + Play Internal | " |
| **8. Submission** | 8 | Privacy policy + ToS published · store listings · screenshots · submit to both stores | " |

**Plan-as-you-go protocol:** Before starting Phase N, write `docs/superpowers/plans/2026-XX-XX-stayon-phase-N-<name>.md` with bite-sized TDD tasks. Stale plans for far-future phases are worse than no plans.

---

## J. Risks & Tradeoffs

| Risk | Mitigation |
|---|---|
| iOS notification permission denial silently breaks core value | Phase 4 includes permission-denied banner + Settings deep link + integration test |
| Supabase Free DB cap (500 MB) | Monitor in beta; Postgres rows are small; attachments live in Storage (1 GB free). Plan to upgrade Pro at ~30k items. |
| OCR-lite heuristics misread → user mistrust | Always show "Pre-filled from photo" hint, always confirm before save. Don't auto-create items from OCR. |
| Local notifications drift after iOS app upgrade | `reconcileReminders()` on every cold start |
| Sign in with Apple required if Google sign-in shipped on iOS (App Store policy) | Implement both in Phase 1 |
| Trash purge job fails silently | Add Sentry capture in Edge Function wrapper; surface row count metric |
| Solo dev burnout | Strict scope: V1 features only; deferred list is sacred |
| Share-link URL collision / brute force | 32-byte tokens (URL-safe), `expires_at` enforced in RLS policy |
| Family tab vs real household sharing expectation gap | Honest copy in V1 ("Manage assignees & active shares — household invites coming soon") |
| `pubspec.lock` churn from Dart upgrades | Pin Flutter version in `.fvmrc` once team grows; for now keep `pubspec.lock` committed |

---

## K. Phase 0 — Project Scaffold (DETAILED)

**Goal:** Stand up a runnable Flutter project with theming, lints, basic CI, and a placeholder home screen. Zero product features yet. End state: `flutter run` shows a themed splash + empty home, `flutter analyze` clean, `flutter test` green.

### Files at the end of Phase 0
- Created: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/theme/colors.dart`, `lib/app/theme/typography.dart`, `lib/app/theme/app_theme.dart`, `lib/app/shell/placeholder_home.dart`, `test/widget_test.dart`, `.github/workflows/ci.yml`, `README.md`, `assets/fonts/` directory + Nunito Sans .ttf files, icon assets.
- Modified: `.gitignore` (already exists; verify Flutter-friendly).

---

### Task 0.1: Install Flutter and confirm toolchain

**Files:** none (environment setup).

- [ ] **Step 1: Install Flutter via your preferred method (manual SDK from flutter.dev or `brew install --cask flutter`)**

Confirm Xcode + CocoaPods + Android Studio with Android SDK 34 are installed (Xcode for iOS, Android Studio for the Android SDK and Gradle).

- [ ] **Step 2: Run doctor**

```bash
flutter doctor -v
```
Expected: all checkmarks for `Flutter`, `Xcode`, `Android toolchain`, `Chrome`. Resolve any red Xs before continuing.

- [ ] **Step 3: Confirm Dart 3.x**

```bash
dart --version
```
Expected: `Dart SDK version: 3.x.x`.

---

### Task 0.2: Create the Flutter project in-place

**Files:** scaffolds the project skeleton into the repo root.

- [ ] **Step 1: Run `flutter create` over the existing directory**

```bash
cd "/Users/mon/Documents/StayOn 2.0"
flutter create \
  --org app.getstayon \
  --project-name stayon \
  --platforms ios,android \
  --description "Never miss what matters." \
  .
```
Expected: `Wrote N files.` Project structure now includes `lib/`, `ios/`, `android/`, `test/`, `pubspec.yaml`.

- [ ] **Step 2: Verify bundle identifiers**

```bash
grep -R "app.getstayon.stayon" ios/Runner.xcodeproj android/app/build.gradle
```
Expected: matches in both `ios/Runner.xcodeproj/project.pbxproj` and `android/app/build.gradle`. Bundle ID will display as `app.getstayon.stayon`; we'll override to `app.getstayon.mobile` in the next step.

- [ ] **Step 3: Rename bundle ID to `app.getstayon.mobile`**

In `ios/Runner.xcodeproj/project.pbxproj`, replace all `app.getstayon.stayon` with `app.getstayon.mobile`.

In `android/app/build.gradle` (or `build.gradle.kts`), set:
```gradle
applicationId "app.getstayon.mobile"
namespace "app.getstayon.mobile"
```

- [ ] **Step 4: First clean run**

```bash
flutter pub get
flutter run -d "iPhone 15"   # or any installed simulator
```
Expected: default counter app launches in simulator.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project (app.getstayon.mobile)"
```

---

### Task 0.3: Pin dependencies

**Files:** Modify `pubspec.yaml`.

- [ ] **Step 1: Replace the `dependencies:` and `dev_dependencies:` blocks in `pubspec.yaml`**

```yaml
environment:
  sdk: '>=3.4.0 <4.0.0'
  flutter: '>=3.22.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  supabase_flutter: ^2.5.6
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  flutter_local_notifications: ^17.2.2
  timezone: ^0.9.4
  flutter_native_timezone_updated_gradle: ^1.1.1
  flutter_secure_storage: ^9.2.2
  image_picker: ^1.1.2
  file_picker: ^8.0.6
  flutter_image_compress: ^2.3.0
  cached_network_image: ^3.4.0
  pdfx: ^2.6.0
  google_mlkit_text_recognition: ^0.13.1
  intl: ^0.19.0
  sentry_flutter: ^8.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.11
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  drift_dev: ^2.18.0
  mocktail: ^1.0.4
```

- [ ] **Step 2: Resolve**

```bash
flutter pub get
```
Expected: no errors. If a version constraint clashes, run `flutter pub upgrade --major-versions <pkg>` for the offending package and update the pin.

- [ ] **Step 3: Sanity-build**

```bash
flutter build apk --debug
```
Expected: build succeeds. (Skip if Android toolchain not set up; substitute `flutter build ios --debug --no-codesign`.)

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: pin V1 dependency set"
```

---

### Task 0.4: Add Nunito Sans font assets

**Files:** Create `assets/fonts/` and add 5 weights of Nunito Sans (300, 400, 600, 700, 900) + italic variants for 400 and 700.

- [ ] **Step 1: Download fonts**

From [fonts.google.com/specimen/Nunito+Sans](https://fonts.google.com/specimen/Nunito+Sans), download the family. Copy these files into `assets/fonts/`:
```
NunitoSans-Light.ttf        (300)
NunitoSans-Regular.ttf      (400)
NunitoSans-Italic.ttf       (400 italic)
NunitoSans-SemiBold.ttf     (600)
NunitoSans-Bold.ttf         (700)
NunitoSans-BoldItalic.ttf   (700 italic)
NunitoSans-Black.ttf        (900)
```

- [ ] **Step 2: Register in `pubspec.yaml`**

Add under `flutter:`:
```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: NunitoSans
      fonts:
        - asset: assets/fonts/NunitoSans-Light.ttf
          weight: 300
        - asset: assets/fonts/NunitoSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/NunitoSans-Italic.ttf
          weight: 400
          style: italic
        - asset: assets/fonts/NunitoSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/NunitoSans-Bold.ttf
          weight: 700
        - asset: assets/fonts/NunitoSans-BoldItalic.ttf
          weight: 700
          style: italic
        - asset: assets/fonts/NunitoSans-Black.ttf
          weight: 900
```

- [ ] **Step 3: Pub get**

```bash
flutter pub get
```

- [ ] **Step 4: Commit**

```bash
git add assets/ pubspec.yaml pubspec.lock
git commit -m "chore: add Nunito Sans font family (weights 300-900)"
```

---

### Task 0.5: Define brand color tokens

**Files:** Create `lib/app/theme/colors.dart`.

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';

/// StayOn brand color tokens. Single source of truth for all UI colors.
abstract final class AppColors {
  // Brand
  static const forest = Color(0xFF0F3D2E);
  static const green = Color(0xFF1F7A4D);
  static const mint = Color(0xFFD6EBDD);
  static const cream = Color(0xFFFAF6EE);
  static const ink = Color(0xFF1A1A1A);

  // Accent
  static const coral = Color(0xFFFF7A5C);

  // Category surfaces
  static const catMedicine = Color(0xFFFFE3D8);
  static const catGrocery = Color(0xFFFFEAC2);
  static const catDocument = Color(0xFFDDEBFF);
  static const catSubscription = Color(0xFFD6EBDD);
  static const catWarranty = Color(0xFFEADBFF);
  static const catBill = Color(0xFFFFE0E6);
  static const catInsurance = Color(0xFFDDEBFF);
  static const catOther = Color(0xFFECECEC);

  // Dark mode
  static const darkBg = Color(0xFF0E1411);
  static const darkSurface = Color(0xFF16201B);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app/theme/colors.dart
git commit -m "feat(theme): add brand color tokens"
```

---

### Task 0.6: Define typography tokens

**Files:** Create `lib/app/theme/typography.dart`.

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';

/// StayOn typography scale, all in Nunito Sans. Use these instead of raw TextStyles.
abstract final class AppTypography {
  static const _family = 'NunitoSans';

  static const displayLg = TextStyle(
    fontFamily: _family, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w900);

  static const displayMd = TextStyle(
    fontFamily: _family, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800);

  static const titleLg = TextStyle(
    fontFamily: _family, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w800);

  static const titleMd = TextStyle(
    fontFamily: _family, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700);

  static const bodyLg = TextStyle(
    fontFamily: _family, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);

  static const bodyMd = TextStyle(
    fontFamily: _family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);

  static const labelSm = TextStyle(
    fontFamily: _family, fontSize: 12, height: 16 / 12,
    fontWeight: FontWeight.w700, letterSpacing: 0.72);

  static const caption = TextStyle(
    fontFamily: _family, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app/theme/typography.dart
git commit -m "feat(theme): add typography scale (Nunito Sans)"
```

---

### Task 0.7: Build the AppTheme (light + dark)

**Files:** Create `lib/app/theme/app_theme.dart`.

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.forest,
      secondary: AppColors.green,
      surface: Colors.white,
      onSurface: AppColors.ink,
    ).copyWith(background: AppColors.cream);

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.cream,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
      primary: AppColors.mint,
      secondary: AppColors.green,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
    ).copyWith(background: AppColors.darkBg);

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NunitoSans',
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLg.copyWith(color: scheme.onSurface),
        displayMedium: AppTypography.displayMd.copyWith(color: scheme.onSurface),
        titleLarge: AppTypography.titleLg.copyWith(color: scheme.onSurface),
        titleMedium: AppTypography.titleMd.copyWith(color: scheme.onSurface),
        bodyLarge: AppTypography.bodyLg.copyWith(color: scheme.onSurface),
        bodyMedium: AppTypography.bodyMd.copyWith(color: scheme.onSurface),
        labelSmall: AppTypography.labelSm.copyWith(color: scheme.onSurface),
        bodySmall: AppTypography.caption.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: AppTypography.titleMd,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLg.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app/theme/app_theme.dart
git commit -m "feat(theme): light + dark Material 3 themes from tokens"
```

---

### Task 0.8: Placeholder home screen

**Files:** Create `lib/app/shell/placeholder_home.dart`.

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('StayOn')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Never miss what matters.', style: t.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Project scaffold ready. Auth and features land in Phase 1.',
              style: t.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app/shell/placeholder_home.dart
git commit -m "feat(app): add placeholder home screen"
```

---

### Task 0.9: Wire main.dart with ProviderScope and themes

**Files:** Overwrite `lib/main.dart`.

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme/app_theme.dart';
import 'app/shell/placeholder_home.dart';

void main() {
  runApp(const ProviderScope(child: StayOnApp()));
}

class StayOnApp extends StatelessWidget {
  const StayOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayOn',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const PlaceholderHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 2: Run the app**

```bash
flutter run -d "iPhone 15"
```
Expected: cream background, "Never miss what matters." in big Nunito Sans Black, app bar reads "StayOn".

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(app): wire ProviderScope + Material 3 light/dark themes"
```

---

### Task 0.10: Stricter analyzer

**Files:** Overwrite `analysis_options.yaml`.

- [ ] **Step 1: Write the file**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore   # freezed compatibility
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.mocks.dart"

linter:
  rules:
    avoid_print: true
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_locals: true
    require_trailing_commas: true
    sort_constructors_first: true
    unawaited_futures: true
    use_key_in_widget_constructors: true
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```
Expected: `No issues found!` If any pop up, fix in `lib/main.dart` or theme files.

- [ ] **Step 3: Commit**

```bash
git add analysis_options.yaml
git commit -m "chore: tighten analyzer + lints"
```

---

### Task 0.11: First widget test

**Files:** Overwrite `test/widget_test.dart`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stayon/main.dart';

void main() {
  testWidgets('Placeholder home renders tagline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayOnApp()));
    expect(find.text('Never miss what matters.'), findsOneWidget);
    expect(find.text('StayOn'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it**

```bash
flutter test
```
Expected: 1 test passes.

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: placeholder home renders tagline"
```

---

### Task 0.12: GitHub Actions CI

**Files:** Create `.github/workflows/ci.yml`.

- [ ] **Step 1: Write the workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  flutter:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.x'
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
          if-no-files-found: ignore
```

- [ ] **Step 2: Commit and push**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: format, analyze, test on push and PR"
git push
```
Expected: workflow appears at https://github.com/ritchworks-ux/stayon2.0/actions and goes green.

---

### Task 0.13: README + tag

**Files:** Create `README.md`.

- [ ] **Step 1: Write a minimal README**

```markdown
# StayOn

Never miss what matters. Track expiry, renewal, and due dates for warranties, subscriptions, IDs, insurance, medicines, groceries, bills, and documents.

- Platforms: iOS 16+, Android 10+
- Stack: Flutter 3.22 · Riverpod · Supabase
- Spec: [docs/superpowers/specs/2026-05-18-stayon-mvp-design.md](docs/superpowers/specs/2026-05-18-stayon-mvp-design.md)
- Plan: [docs/superpowers/plans/2026-05-18-stayon-mvp.md](docs/superpowers/plans/2026-05-18-stayon-mvp.md)

## Run locally

```bash
flutter pub get
flutter run
```

## Quality gates

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```
```

- [ ] **Step 2: Commit and tag**

```bash
git add README.md
git commit -m "docs: add README"
git tag -a v0.1-scaffold -m "Phase 0: project scaffold"
git push --tags
```

---

### Phase 0 exit gate (run all green before declaring done)

- [ ] `dart format --set-exit-if-changed .` → clean
- [ ] `flutter analyze --fatal-infos` → `No issues found!`
- [ ] `flutter test` → 1 passed
- [ ] `flutter run` opens placeholder home in cream + Nunito Sans
- [ ] CI workflow shows green on `main`
- [ ] Tag `v0.1-scaffold` pushed

---

## L. Next-phase planning prompt (for reuse)

Before each subsequent phase, write the detailed plan with this prompt to keep style consistent:

> "Write `docs/superpowers/plans/2026-XX-XX-stayon-phase-N-<name>.md` for Phase N of StayOn. Use the writing-plans skill format: bite-sized TDD tasks (2–5 min each), exact file paths, complete code in every step, exact commands with expected output, commit after every step. Reference the spec at [docs/superpowers/specs/2026-05-18-stayon-mvp-design.md](../specs/2026-05-18-stayon-mvp-design.md). End with a phase exit gate (format/analyze/test/manual run) and a `v0.N-<name>` tag."

---

## Self-Review Notes

**Spec coverage:** all 18 spec sections are addressed somewhere — sections A–H of this plan summarize them; Phase 0 covers theme/typography/Material 3 setup; Phases 1–8 in section I cover the rest with `plan-as-you-go` for detail. `amount_minor` is explicitly noted as captured in V1 (schema phase, Phase 2) so V1.5 Insights ships without migration.

**Placeholder scan:** no "TBD" / "implement later" / "similar to". Phase 0 tasks contain complete code; phases 1–8 are deliberately milestone-level with a written commitment to detailed plans before each phase begins.

**Type consistency:** color and typography token names used in `AppTheme` match the definitions in `AppColors` / `AppTypography`. Bundle ID `app.getstayon.mobile` consistent across spec, Task 0.2, and Task 0.2 Step 3.
