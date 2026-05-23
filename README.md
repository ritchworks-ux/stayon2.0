# StayOn

Never miss what matters. Track expiry, renewal, and due dates for warranties, subscriptions, IDs, insurance, medicines, groceries, bills, and documents.

- **Platforms:** iOS 16+, Android 10+ (web target enabled for development preview only)
- **Stack:** Flutter 3.41 · Riverpod 2 · go_router 14 · Supabase · Drift · Nunito Sans
- **Bundle ID:** `app.getstayon.mobile`
- **Spec:** [docs/superpowers/specs/2026-05-18-stayon-mvp-design.md](docs/superpowers/specs/2026-05-18-stayon-mvp-design.md)
- **Master plan:** [docs/superpowers/plans/2026-05-18-stayon-mvp.md](docs/superpowers/plans/2026-05-18-stayon-mvp.md)
- **Phase 1 plan:** [docs/superpowers/plans/2026-05-18-stayon-phase-1-auth.md](docs/superpowers/plans/2026-05-18-stayon-phase-1-auth.md)
- **Phase 2 plan:** [docs/superpowers/plans/2026-05-18-stayon-phase-2-items.md](docs/superpowers/plans/2026-05-18-stayon-phase-2-items.md)
- **Phase 2.5 plan:** [docs/superpowers/plans/2026-05-22-stayon-phase-2.5-ux-polish.md](docs/superpowers/plans/2026-05-22-stayon-phase-2.5-ux-polish.md)

---

## Run locally

### 1. Prerequisites

- Flutter 3.41+ (`flutter --version`)
- Dart 3.11+
- A Supabase project — see [Supabase setup](#supabase-setup) below

### 2. Configure environment

Copy [`.env.example`](.env.example) to `.env.local` (which is gitignored) and fill in your Supabase project values:

```
SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

The publishable key is safe to ship — Row-Level Security on every table is what actually protects data. **Never** put `sb_secret_*` / `service_role` keys, the database password, or direct Postgres connection strings in this file or anywhere in the app.

### 3. Run

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.local
```

Other targets:
```bash
flutter run --dart-define-from-file=.env.local                # auto-select device
flutter run -d "iPhone 15" --dart-define-from-file=.env.local # iOS simulator
flutter build web --dart-define-from-file=.env.local           # web release build
```

Web is enabled for development preview only — V1 ships iOS + Android.

---

## Supabase setup

If you're starting fresh, create your own project (the same one cannot be shared across developers — RLS is keyed to `auth.uid()`):

1. Create a project at https://supabase.com/dashboard. Region **Southeast Asia (Singapore) `ap-southeast-1`** for PH-friendly latency.
2. Project Settings → API — copy **Project URL** and **publishable key** (`sb_publishable_*`) into your `.env.local`. **Skip** the `sb_secret_*` key — it's never used by this app.
3. Authentication → Providers → **Email**: leave enabled, set **Confirm email** to ON.
4. SQL Editor → New query → paste [`supabase/migrations/0001_profiles.sql`](supabase/migrations/0001_profiles.sql) → Run. This creates the `profiles` table with **RLS enabled** and three owner-only policies (`profiles_select_own`, `profiles_insert_own`, `profiles_update_own`).

Verify in Table Editor that `profiles` exists with a green **RLS enabled** badge before running the app.

### Security guardrails

- `.env.local` is in [`.gitignore`](.gitignore) (matched by `.env.*`). Never commit it.
- Every table added in V1+ must have RLS **enabled** with explicit owner-scoped policies *before* exposing it to the client. The `0001_profiles.sql` migration is the reference pattern.
- The publishable key is **only** safe when RLS is enforced on every user-data table — RLS off means the publishable key reads everything.
- Service-role / `sb_secret_*` keys must never appear in the Flutter app, in `.env.local`, in CI secrets used by client builds, or in shared chat logs. They bypass RLS.
- Database password and direct Postgres connection strings stay in your Supabase account / password manager only.
- Account-deletion in app + privacy policy + ToS are required before App/Play Store submission (Phase 6 / 8).

---

## Phase 2.5 status — UX Polish (tag [`v0.4-ux-polish`](https://github.com/ritchworks-ux/stayon2.0/releases/tag/v0.4-ux-polish))

### Shipped

- **Date-type-aware labels** — `relativeDateLabel` now shows "Expires in 3 days", "Renews tomorrow", "Due today" etc. based on `ItemDateType`; overdue copy stays type-agnostic
- **Past-date warning** — Add Item form shows a coral info row (`AnimatedSwitcher` cross-fade) when the selected date is in the past; Edit mode intentionally omits it
- **Overdue badge** — Alerts nav destination shows a live `Badge.count` driven by `itemsProvider`; hidden when count is zero
- **Dark-mode category surfaces** — All 9 category colors have matching dark tokens; `surfaceFor(context)` method picks the right token automatically
- **Settings screen** — `/settings` route with Light / System / Dark `ChoiceChip` toggle wired to `MaterialApp.themeMode`; Settings entry enabled in Home header
- **Richer Home dashboard** — ThisWeekHeroCard (due-soon count + overdue callout), StatTiles (Due soon / Upcoming), time-aware greeting
- **Test suite** — 131 tests, 0 failures; `flutter analyze --fatal-infos` clean

### Known limitations (intentional, deferred)

| Limitation | Resolves in |
|---|---|
| Theme preference resets on cold start (no persistence) | Phase 3+ |
| Calendar / Alerts / Family tabs are stubs | Phases 5–6 |
| No search / filter on Home | Phase 4 |
| Attachments not yet supported | Phase 3 |
| No reminders / push notifications | Phase 4 |

---

## Phase 2 status — Items CRUD (tag [`v0.3-items`](https://github.com/ritchworks-ux/stayon2.0/releases/tag/v0.3-items))

### Shipped

- Full Add / Edit / Archive / Delete / Restore item flow with Supabase backend
- Item Detail route `/item/:id` with full field display and action row
- Undo snackbar for archive + delete (5-second window, navigates to Home first)
- Home dashboard with bucketed sections (Overdue / This week / This month / Later) + pull-to-refresh
- 7 item categories with icon + color; PHP currency support (minor-unit arithmetic)
- Supabase RLS migrations `0002_items.sql` + `0003_items_rls.sql`

---

## Phase 1 status — Auth + App shell (tag [`v0.2-auth`](https://github.com/ritchworks-ux/stayon2.0/releases/tag/v0.2-auth))

### Shipped

- Email + password **sign-up** (Supabase Auth, PKCE flow)
- Email verification gate (`Confirm email` ON)
- Email + password **sign-in**
- **Profile row bootstrap** — `profiles` row inserted automatically on first sign-in via idempotent upsert under RLS
- **Sign-out** — auth state stream emits null → router redirects to `/auth/sign-in`
- **Auth guard** — direct navigation to any protected route (`/home`, `/calendar`, `/alerts`, `/family`) while signed-out redirects to `/auth/sign-in`; signed-in users on `/auth/*` redirect to `/home`
- **App shell** — Material 3, light + dark themes, Nunito Sans variable font, bottom-nav (Home / Calendar / Alerts / Family) with centered FAB
- **Home screen** — hero-matched layout: greeting (display name → email prefix fallback), logout icon, empty-state card
- **Tab stubs** — Calendar, Alerts, Family render placeholder content stamped with their target phase
- **FAB** — visible on every tab; shows snackbar "Add Item arrives in Phase 2"
- **Test coverage** — 10 unit + widget + router tests including the sign-out router regression
- **CI** — GitHub Actions runs format + analyze + test on every push and PR

### Known limitations (intentional, deferred)

| Limitation | Resolves in |
|---|---|
| No Google / Apple sign-in | Phase 1b (needs Apple Developer enrollment + Google Cloud OAuth setup) |
| Email verification link redirects to default `localhost:3000` and shows a Supabase landing page | Phase 1b (configure Supabase Site URL + custom redirect) |
| No actual items, attachments, reminders | Phases 2–4 |
| Calendar / Alerts / Family tabs are stubs | Phases 5–6 |
| No account-deletion UI | Phase 6 |
| No password reset flow | Phase 1b |
| Web is dev-only, no responsive layout work | V3 |

---

## Quality gates

CI runs all three on every push and PR — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Locally:

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter build web --dart-define-from-file=.env.local
```

---

## Repository layout

```
lib/
  app/                    # theme, router, shell
    theme/                # color + typography tokens, Material 3 themes
    router/               # go_router with auth guard
    shell/                # bottom-nav app shell
  core/
    config/               # env reader (--dart-define values)
    services/             # SupabaseService init wrapper
    models/               # freezed shared models
  features/
    auth/                 # repo + controller + sign-in/up screens
    home/                 # dashboard with sections, hero card, stat tiles
    items/                # CRUD: category, date, money, form, card, detail
    settings/             # theme toggle + app info
    calendar/             # stub
    alerts/               # stub
    family/               # stub
supabase/
  migrations/             # SQL files run manually in dashboard (no service-role usage)
docs/
  superpowers/
    specs/                # design spec
    plans/                # implementation plans per phase
test/
  app/router/             # router redirect tests
  app/shell/              # overdue badge tests
  core/models/            # item, money unit tests
  features/auth/          # controller + sign-in widget tests
  features/home/          # dashboard + greeting tests
  features/items/         # buckets, card, form, detail, undo tests
  widget_test.dart        # app boot smoke
```
