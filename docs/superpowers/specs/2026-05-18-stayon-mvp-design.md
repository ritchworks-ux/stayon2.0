# StayOn — MVP Design Spec

- **Date:** 2026-05-18
- **App name:** StayOn
- **Bundle ID:** `app.getstayon.mobile`
- **Domain:** `getstayon.app` (primary), `getstayon.ph` (optional PH redirect)
- **Platforms:** iOS 16+ and Android 10+ (Flutter, single codebase)
- **Launch region:** Philippines (English-only UI), product built region-flexible
- **Monetization in V1:** none (free)

---

## 1. Product positioning

**Tagline:** *Never miss what matters.*

**One-liner:** The shoebox for everything with a date on it — warranties, subscriptions, IDs, insurance, medicines, groceries, bills, documents — gathered in one calm place for the whole family.

**Not:** a notes app, a to-do app, a document vault, a budgeting app. Resist scope creep toward any of these.

## 2. Target users

- **Primary:** Adults 25–55 managing a household in the Philippines (PhilHealth, LTO, Meralco, SSS, BIR renewals; family insurance; kids' IDs).
- **Secondary:** Young professionals tracking subscriptions, visas, prescriptions.
- **Tertiary:** Solo business owners tracking permits, licenses, warranties.
- **Anti-persona:** Power users wanting Notion-style flexibility.

## 3. Brand identity

### Logo
Friendly calendar-mascot (existing): rounded calendar tile with smile + check mark. Variants needed:
- App icon (square, no wordmark, 1024×1024 + adaptive Android)
- Horizontal wordmark (existing hero)
- Monogram "S" (favicon, splash, watch fallback)

### Color tokens

| Token | Hex | Use |
|---|---|---|
| `brand/forest` | `#0F3D2E` | Headlines, logo mark, primary buttons |
| `brand/green` | `#1F7A4D` | Active states, FAB, success states |
| `brand/mint` | `#D6EBDD` | Selected chips, soft highlight cards |
| `brand/cream` | `#FAF6EE` | Light-mode app background |
| `brand/ink` | `#1A1A1A` | Body text on cream |
| `accent/coral` | `#FF7A5C` | Underline accent, "attention" CTAs (sparingly) |
| `cat/medicine` | `#FFE3D8` | Medicine card background |
| `cat/grocery` | `#FFEAC2` | Grocery card background |
| `cat/document` | `#DDEBFF` | Document / Health card background |
| `cat/subscription` | `#D6EBDD` | Subscription card background |
| `cat/warranty` | `#EADBFF` | Warranty card background |
| `cat/bill` | `#FFE0E6` | Bill card background |
| `cat/insurance` | `#DDEBFF` | Insurance card background |
| `cat/other` | `#ECECEC` | Other card background |
| `dark/bg` | `#0E1411` | Dark-mode background |
| `dark/surface` | `#16201B` | Dark-mode surface |

Card shadow: `0 2px 8px rgba(15,61,46,0.08)`. Corner radii: 16px cards, 20px hero cards, 12px buttons.

### Typography (Nunito Sans, full weight range)

| Token | Size / Line | Weight | Use |
|---|---|---|---|
| `display/lg` | 34 / 40 | 900 | Onboarding headlines |
| `display/md` | 28 / 34 | 800 | "Good morning, Rohan" |
| `title/lg` | 22 / 28 | 800 | Screen titles ("Alerts") |
| `title/md` | 18 / 24 | 700 | Card titles ("Health Insurance") |
| `body/lg` | 16 / 24 | 400 | Default body |
| `body/md` | 14 / 20 | 400 | Secondary text |
| `label/sm` | 12 / 16 | 700 uppercase tracked +0.06em | Category tags |
| `caption` | 11 / 14 | 600 | Meta dates ("May 25") |

Numbers in stat cards use tabular figure variant. No secondary font in the app. (Optional **Fraunces** pair on marketing site only.)

## 4. Core MVP (V1) feature set

1. Email/password + Google + Apple sign-in (Supabase Auth)
2. Add/edit item: name, category, `date_type` (expires/renews/due), `target_date`, notes, assignee label, optional amount in PHP
3. Multi-attachment per item: up to 5 files; image (≤10MB, auto-compressed to 1600px JPEG q85) or PDF
4. Preset categories (no custom in V1): Warranty, Subscription, ID/License, Insurance, Medicine, Grocery, Bill, Document, Other
5. Home dashboard matching hero: greeting, "This week" hero card, two stat tiles (Due soon, Upcoming), Upcoming list, FAB `+`
6. Calendar tab: month grid showing item dots; tap day → list of items on that date
7. Alerts tab: Upcoming / Today / Overdue tabs matching hero
8. Family tab (V1 = People & Shares): list of assignee labels in use + list of active share links with revoke (no real household invites in V1)
9. Item detail: attachment carousel, fields, reminder schedule, action row (Share link, Mark renewed, Archive, Delete → Trash)
10. Local push notifications (default offsets: 7d + 1d before at 09:00 Asia/Manila; per-item override)
11. **OCR-lite pre-fill** on Add Item: snap a document → on-device Google ML Kit Text Recognition extracts text → app suggests `name` (first line) and `target_date` (best date match) → user confirms
12. Search by name + category-chip filter
13. Read-only share link per item: signed token, configurable expiry (24h / 7d / 30d / never), revocable
14. **Soft delete / Trash:** deleted items move to Trash, auto-purge after 30 days, restorable
15. Manual backup export: JSON + zipped attachments via native share sheet
16. Settings: account, default reminder offsets, theme (light/dark/system), backup/export, delete account (cascade), privacy/ToS, about

## 5. Explicitly deferred

| Feature | Target |
|---|---|
| Multi-item grocery receipt OCR + shelf-life suggestions | V2 (premium candidate, uses LLM) |
| Insights / spend analytics | V1.5 (amount field captured in V1 to avoid migration) |
| Barcode scanning | V1.5 |
| Recurring auto-renewal logic | V1.5 |
| Custom categories | V2 |
| Real shared households (invites + roles + realtime) | V2 |
| Calendar sync (Google / iOS) | V2 |
| Widgets | V2 |
| CSV import | V2 |
| In-app purchases / Pro tier | When monetizing |
| Email forwarding inbox | V3 |
| Apple Watch | V3 |
| Tags | V3 |
| Custom themes | V3 |
| Location reminders | Skip / V3 |
| Web app | V3 |

## 6. Main user flows

- **Onboarding:** Splash → auth → 3-screen value pitch → notification permission prompt → empty home with "+ Add your first item"
- **Add item (manual):** FAB `+` → form → save → toast "Reminder set for X" → home
- **Add item (OCR-lite):** FAB `+` → "Scan a document" → camera → ML Kit extracts → confirm pre-filled fields → save
- **Get reminded:** Local notification → tap → item detail
- **Find item:** Home or Search tab → type / chip filter → detail
- **Share:** Item detail → Share link → choose expiry → native share sheet
- **Renew:** Item detail → Mark renewed → enter new `target_date` → reminders rescheduled
- **Archive / Delete:** Detail → Archive (hidden but searchable) or Delete (to Trash, 30-day restore window)

## 7. Screen inventory

1. Splash
2. Auth (Sign in / Sign up tabs)
3. Onboarding carousel (3 screens, shown once)
4. Home / Dashboard (hero-matched layout)
5. Calendar tab (month view)
6. Alerts tab (Upcoming / Today / Overdue)
7. Family tab (People & Shares)
8. Add / Edit Item (modal sheet, multi-section)
9. OCR Scan flow (camera → confirm fields)
10. Item Detail (attachment carousel + actions)
11. Attachment Viewer (full-screen image / PDF)
12. Search
13. Notifications history
14. Trash
15. Settings → Account
16. Settings → Default reminders
17. Settings → Backup / Export
18. Settings → Theme
19. Settings → Delete account
20. About / Privacy / ToS

Bottom nav (matches hero): **Home · Calendar · `+` (FAB) · Alerts · Family**. Top-right of Home is the bell (opens Alerts tab). Settings reached by tapping the user avatar next to the "Good morning, {name}" greeting on Home.

## 8. Flutter architecture

- **Flutter 3.x stable**, Dart 3, Material 3 with custom `ColorScheme.fromSeed` overridden by tokens above.
- **State:** `flutter_riverpod` (controllers + providers; no business logic in widgets).
- **Routing:** `go_router` with typed routes and deep-link support for share URLs.
- **Backend:** **Supabase** (Postgres + Auth + Storage + RLS).
- **Local cache:** `drift` (SQLite) mirrors `items` + `reminders` for offline read and local notification scheduling. Attachments cached on demand to app documents dir.
- **Codegen:** `freezed` + `json_serializable` for models; `drift_dev` for DB.
- **Layered structure:**
  ```
  lib/
    main.dart
    app/                  // theme, router, app shell
    features/
      auth/
      items/
      attachments/
      reminders/
      sharing/
      family/
      ocr/
      trash/
      settings/
    core/
      models/             // freezed
      services/           // SupabaseService, NotificationService, FileService, OcrService
      utils/
  ```
- **Layering:** UI → Riverpod controller → Repository → Service.

### Key dependencies

| Package | Purpose |
|---|---|
| `supabase_flutter` | Backend client |
| `flutter_riverpod` | State |
| `go_router` | Routing + deep links |
| `freezed`, `json_serializable` | Models |
| `drift` | Local SQLite cache |
| `flutter_local_notifications`, `timezone` | Reminders |
| `flutter_secure_storage` | Session tokens |
| `image_picker`, `file_picker` | Attachments |
| `flutter_image_compress` | Image compression |
| `cached_network_image` | Thumbnails |
| `pdfx` | PDF preview |
| `google_mlkit_text_recognition` | OCR-lite |
| `mobile_scanner` | (V1.5) barcode |
| `intl` | Locale-aware dates / currency |
| `sentry_flutter` | Crash reporting |

## 9. Data model (Supabase Postgres)

```sql
profiles (
  id uuid PK = auth.uid,
  display_name text,
  default_reminder_offsets int[] default '{7,1}',
  created_at timestamptz default now()
)

items (
  id uuid PK,
  owner_id uuid FK profiles on delete cascade,
  name text not null,
  category text not null check (category in
    ('warranty','subscription','id_license','insurance',
     'medicine','grocery','bill','document','other')),
  date_type text not null check (date_type in ('expires','renews','due')),
  target_date date not null,
  notes text,
  assignee_label text,
  amount_minor int,                    -- store in minor units (centavos)
  currency_code text default 'PHP',
  status text default 'active' check (status in ('active','archived','trashed')),
  trashed_at timestamptz,              -- set when status -> trashed, purged 30d later
  created_at timestamptz default now(),
  updated_at timestamptz default now()
)

attachments (
  id uuid PK,
  item_id uuid FK items on delete cascade,
  storage_path text not null,
  mime_type text,
  size_bytes int,
  created_at timestamptz default now()
)

reminders (
  id uuid PK,
  item_id uuid FK items on delete cascade,
  offset_days int not null,
  local_notification_id int,
  fire_at timestamptz                  -- pre-computed for diff/reconcile
)

share_links (
  id uuid PK,
  item_id uuid FK items on delete cascade,
  token text unique not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz default now()
)
```

### Row-Level Security
- `profiles`, `items`, `attachments`, `reminders`: read/write only where `owner_id = auth.uid()` (joining via `item_id` for child tables).
- `share_links`: owner-only insert/update/delete; public-read scoped to non-revoked, non-expired rows by `token`.
- Storage bucket `attachments`: path scoped `{user_id}/{item_id}/{uuid}.{ext}`; RLS policy restricts to owner. Share-link reads use signed URLs generated server-side via Edge Function.

### Scheduled jobs
- Supabase `pg_cron` daily job purges items with `status='trashed' AND trashed_at < now() - interval '30 days'` (cascades attachments).

## 10. Reminder & notification logic

- **Library:** `flutter_local_notifications` + `timezone` (no FCM in V1).
- **On item save/edit:** for each reminder, compute `target_date - offset_days @ 09:00 device_tz`. Cancel old `local_notification_id`s, schedule new ones, persist new IDs.
- **On app launch:** reconcile — fetch items from Supabase, diff against pending OS notifications, re-schedule drift.
- **Default offsets:** `[7, 1]` days before. User-editable globally and per-item.
- **Edge cases:** `target_date` in the past → skip schedule, show "Overdue" badge. iOS permission denied → in-app banner explaining + deep link to Settings.

## 11. Attachment & file handling

- **Pick:** `image_picker` (camera + gallery) + `file_picker` (PDF).
- **Pre-upload:** compress images to ≤1600px JPEG q85; reject files >10MB; cap 5 attachments per item.
- **Upload:** Supabase Storage path `{user_id}/{item_id}/{uuid}.{ext}`.
- **Display:** thumbnails via 1-hour signed URLs, cached with `cached_network_image`.
- **PDF:** `pdfx` viewer.
- **Delete:** cascade on item delete via storage repository sweep (Edge Function or client-side on delete).

## 12. OCR-lite pre-fill (V1)

- **Engine:** `google_mlkit_text_recognition` (on-device, free, no API calls).
- **Flow:** Camera capture → ML Kit returns text blocks → heuristic extractor:
  - `name` ← longest line in top 25% of image (with stop-word filtering)
  - `target_date` ← regex match on common formats (`MM/DD/YYYY`, `DD MMM YYYY`, `MMM YYYY`); if multiple, pick the latest future date
  - `category` ← keyword match table (e.g. "PhilHealth" → ID/License, "Meralco" → Bill)
- **Confidence:** show extracted fields in editable form with a small "Pre-filled from photo" hint; user always confirms.
- **No multi-item receipt parsing in V1.**

## 13. Localization & PH defaults

- **Language:** English only in V1. Strings wrapped in `flutter_localizations` from day one so Tagalog/Cebuano can land without refactor.
- **Currency:** stored as minor units + `currency_code`; default `PHP` formatted `₱1,234.50` via `intl.NumberFormat.currency`.
- **Dates:** locale-aware via `intl.DateFormat`; PH default `MMM d, y`.
- **Timezone:** default `Asia/Manila`; respect device override.
- **Seed content:** onboarding sample items + preset assignees tuned to PH context (PhilHealth, LTO, Meralco, SSS, BIR, family roles).
- **No region lock** — installable globally.

## 14. Privacy, security, compliance

- Supabase Auth (email verification on, 8-char min, social sign-in).
- TLS everywhere; data encrypted at rest by Supabase.
- RLS on every user-data table; share-link reads gated by token + expiry + revoked check.
- Sessions stored in `flutter_secure_storage` (Keychain / Keystore).
- No analytics in V1. If added in V1.5, **opt-in PostHog**, never log item names/contents.
- Account deletion in-app (App Store requirement): cascades all data.
- Privacy policy + ToS live at `getstayon.app/privacy`, `/terms` before store submission.
- Data residency note: Supabase EU/US default; pick `ap-southeast-1` (Singapore) region for lowest PH latency.

## 15. Testing checklist

- **Unit:** repositories (mocked Supabase), reminder offset math, date/timezone helpers, OCR field extractor, signed-URL generator, soft-delete purge logic.
- **Widget:** Add Item form validation, Home empty / loaded / error, Item Detail action row, Trash restore.
- **Integration (`integration_test`):** sign-up → add item → verify in DB → schedule local notification → assert pending; delete → Trash → restore → purge after fake clock advance.
- **Manual matrix:** iOS 16/17/18, Android 10/13/14; light + dark; small + large phones; airplane-mode add (queued).
- **Pre-launch:** notification fires when locked / backgrounded / killed; permission-denial paths; share link opens in browser for non-installed recipients.

## 16. Cost model

### Beta (≤50 users)

| Item | Tool | Cost |
|---|---|---|
| Backend (DB/Auth/Storage/Edge Fns) | Supabase Free | $0 |
| Push | `flutter_local_notifications` | $0 |
| OCR | Google ML Kit on-device | $0 |
| Crash reporting | Sentry Developer (5k events) | $0 |
| Source / CI | GitHub Free + Codemagic Free (500 min) | $0 |
| Design | Figma Free | $0 |
| **Apple Developer Program** | required | **$99 / yr** |
| **Google Play Developer** | one-time | **$25** |
| Domain | Namecheap/Porkbun | **~$12 / yr** |
| **Total first year** | | **~$136** |

### Growth (1k–10k users, V1.5)
- Stay on Supabase Free until DB or storage cap; upgrade to **Supabase Pro $25/mo** when needed.
- Opt-in PostHog Free (1M events/mo).

### V2 receipt-AI
- Claude Haiku ≈ $0.001 per receipt. Free users capped at 5/mo; Pro users unlimited. Should be net-positive.

### Active no-spend list
- No Firebase, no AWS/GCP-from-scratch, no OneSignal Pro, no Auth0, no Crashlytics on Blaze.

## 17. Development roadmap (solo, ~8 weeks)

| Week | Milestone |
|---|---|
| 0 | Flutter scaffold, Supabase project, theming, routing skeleton, CI lint, design tokens |
| 1 | Auth + app shell + bottom nav + empty home |
| 2 | Items CRUD + Supabase tables + RLS + Drift cache |
| 3 | Attachments (pick, compress, upload, view) |
| 4 | Reminders (schedule, edit, reconcile, defaults UI) |
| 5 | OCR-lite + Search + Calendar tab + Alerts tab |
| 6 | Family tab (People & Shares) + share-link flow + Trash + Settings + export |
| 7 | Polish: onboarding, empty states, dark mode, accessibility, icons, splash; TestFlight + Play Internal beta |
| 8 | Beta fixes, privacy policy, store listings, screenshots, submission |

## 18. First five coding tasks

1. `flutter create stayon` with `app.getstayon.mobile`, set up Material 3 theme using tokens above + Nunito Sans.
2. Add base deps: `flutter_riverpod`, `go_router`, `supabase_flutter`, `freezed`, `json_serializable`, `drift`, `flutter_local_notifications`, `timezone`, `flutter_secure_storage`, `intl`, `sentry_flutter`.
3. Create Supabase project (region `ap-southeast-1`), commit migration SQL for all tables + RLS policies + `pg_cron` purge job to `supabase/migrations/`.
4. Implement `SupabaseService` singleton + `AuthRepository` + Sign-in/Sign-up screens with form validation and secure session storage.
5. Build app shell: `go_router` routes (`/auth`, `/home`, `/calendar`, `/alerts`, `/family`, `/item/:id`, `/settings`), bottom nav matching hero, centered FAB.

---

## Decisions locked (from brainstorming)

- Cloud-first, account required (Supabase)
- Solo account; V1 sharing = per-item signed read-only link; Family tab = People & Shares
- Free, no IAP in V1
- Manual entry + **OCR-lite single-document pre-fill (on-device ML Kit)** in V1
- Soft delete with 30-day Trash in V1
- Bundle ID `app.getstayon.mobile`, domain `getstayon.app`
- PH launch, English UI, PHP default, region-flexible architecture
