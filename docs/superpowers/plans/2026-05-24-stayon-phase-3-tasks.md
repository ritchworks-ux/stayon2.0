# Phase 3 Implementation Plan: 2-Week Sprint Breakdown

**Phase:** 3 (Attachments + Image Processing)  
**Duration:** 10 working days (2 weeks)  
**Release Target:** v0.5-attachments  
**Workflow:** TDD + git; daily async to Codex; code-reviewer proactive review  

---

## Sprint Structure

```
Week 1 (Days 1–5):
  Migrations + Data Models + Stream 3A (Barcode) foundation
  
Week 2 (Days 6–10):
  Stream 3B (OCR) + Stream 3C (Tiers) + Integration tests
```

---

## Day 1: Supabase Migrations + Drift Setup

### Tasks

**T1.1: Apply 0004_attachments.sql migration**
- [ ] SSH to Supabase SQL Editor
- [ ] Create `public.attachments` table with RLS policies
- [ ] Create `public.storage_quotas` table with RLS
- [ ] Verify indexes (owner_id, item_id)
- [ ] Verify RLS policies are enabled
- **Owner:** user (manual Supabase console)
- **Tests:** None (manual verification in Supabase Dashboard)

**T1.2: Create Drift schema + codegen**
- [ ] Create `lib/core/models/attachment.dart` (freezed)
- [ ] Create `lib/core/models/storage_quota.dart` (freezed)
- [ ] Create `lib/features/attachments/data/attachment_dao.dart` (Drift DAO)
- [ ] Create `lib/features/attachments/data/quota_dao.dart` (Drift DAO)
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify generated files in `.g.dart`
- **Owner:** backend-developer
- **Tests:** Model freezed tests (immutability)

### Subtasks
- Update `pubspec.yaml` if needed (should be done in setup)
- Ensure `drift_dev` is in dev_dependencies

### Commit
```
feat: Phase 3 data models and Drift setup

- Applied 0004_attachments.sql (attachments + storage_quotas tables with RLS)
- Created Attachment, ExtractionResult, StorageQuota freezed models
- Generated Drift DAOs for attachments and quotas (TDD-ready)
```

---

## Day 2: Barcode Scanner Widget + Camera Permission Flow

### Tasks

**T2.1: Barcode Scanner Widget (mobile_scanner)**
- [ ] Create `lib/features/attachments/ui/barcode_scanner_sheet.dart`
- [ ] Implement camera permission request (permission_handler or built-in)
- [ ] Live barcode preview with scanner overlay
- [ ] Haptic feedback on successful scan
- [ ] "Settings" button fallback (permission denied)
- [ ] Loading state while initializing camera
- **Owner:** frontend-developer
- **Tests:**
  - Widget test: barcode scan success flow
  - Widget test: camera permission denied → show Settings button

**T2.2: Barcode Scanner Provider (Riverpod)**
- [ ] Create `lib/features/attachments/controllers/barcode_provider.dart`
- [ ] State: loading | success(barcode) | error(message)
- [ ] Expose stream: `StreamProvider<String>` (scanned barcode)
- **Owner:** backend-developer
- **Tests:** Unit test with mock camera

### Subtasks
- Test on simulator (Android + iOS if time permits)
- Verify haptic feedback works on real device

### Commit
```
feat: Barcode scanner widget and permission flow

- Created barcode_scanner_sheet with mobile_scanner integration
- Implemented camera permission request + Settings fallback
- Added barcode_provider (Riverpod StateNotifier)
- Widget tests for scanner and permission flow
```

---

## Day 3: Open Food Facts HTTP Client + Retry Logic

### Tasks

**T3.1: Open Food Facts API Client**
- [ ] Create `lib/features/attachments/services/open_food_facts_service.dart`
- [ ] Endpoint: `GET /api/v3/product/{barcode}.json`
- [ ] Parse response → extract name, brands, expiration_date
- [ ] Handle errors: 404 (not found), 429 (rate limit), 5xx (server)
- [ ] Retry logic: exponential backoff (max 3 attempts, 1s + 2s + 4s)
- **Owner:** api-architect
- **Tests:**
  - Unit test: successful lookup
  - Unit test: 404 not found
  - Unit test: retry on 5xx (mock delay)
  - Unit test: rate limit handling

**T3.2: Drift Caching (cached_products)**
- [ ] Create `cached_products` table in Drift
- [ ] Migration: `0004_attachments.sql` (add table)
- [ ] Cache hit logic: check Drift before API
- [ ] Staleness: no TTL (cached forever; clear on demand)
- **Owner:** backend-developer
- **Tests:** Cache hit/miss unit tests

### Subtasks
- Test API rate limiting in CI (mock 429 responses)
- Benchmark: API latency + cache hit time

### Commit
```
feat: Open Food Facts integration with caching and retry

- Created open_food_facts_service with exponential backoff retry
- Added cached_products table in Drift for offline resilience
- Implemented cache-first lookup strategy
- Unit tests for API client and cache logic
```

---

## Day 4: Barcode → Item Form Wire-Up + Fallback Entry

### Tasks

**T4.1: Barcode to Item Form Integration**
- [ ] Modify `ItemFormSheet` to accept optional barcode_result parameter
- [ ] If barcode result present: pre-populate name, category
- [ ] User can edit/confirm
- [ ] Save attachment record (type: 'barcode', extraction_data: {code, product_name})
- **Owner:** frontend-developer
- **Tests:**
  - Widget test: barcode scan → item form pre-fill → save

**T4.2: Fallback Manual Entry**
- [ ] If barcode lookup fails: show manual name entry field
- [ ] Display scanned barcode number for reference
- [ ] Allow user to proceed without barcode data
- **Owner:** frontend-developer
- **Tests:** Widget test: barcode not found → manual entry flow

**T4.3: Create Attachment Record**
- [ ] Create `lib/features/attachments/data/attachment_repository.dart`
- [ ] Implement `saveAttachment()` (create Attachment + sync to Supabase)
- [ ] Implement `fetchAttachments(itemId)` (fetch by item)
- **Owner:** backend-developer
- **Tests:**
  - Unit test: saveAttachment with RLS
  - Unit test: fetchAttachments filtering

### Subtasks
- Update Home screen FAB → show barcode or receipt option
- Add "Scan barcode" button to ItemFormSheet header

### Commit
```
feat: Barcode extraction → Item form integration

- Wired barcode_scanner_sheet → ItemFormSheet data pre-fill
- Added fallback manual entry for barcode not found
- Created AttachmentRepository with Supabase sync
- Widget tests for full barcode → item creation flow
```

---

## Day 5: Refactor + Tests + PR

### Tasks

**T5.1: End-to-End Barcode Test**
- [ ] Integration test: camera permission → scan → Open Food Facts → item created
- **Owner:** backend-developer
- **Tests:** Integration test (mock camera, mock API)

**T5.2: Code Review Prep**
- [ ] Run `dart format lib test` (auto-format)
- [ ] Run `flutter analyze --fatal-infos` (zero warnings)
- [ ] Run `flutter test` (100% pass rate)
- [ ] Update README: link to Phase 3 spec + Stream 3A status
- **Owner:** user (manual)

**T5.3: Create PR + Request Review**
- [ ] Push branch `feature/phase-3a-barcode`
- [ ] Create PR with description (link Phase 3 spec)
- [ ] Tag `@code-reviewer` for proactive review
- [ ] Address feedback; merge
- **Owner:** user (manual git/GitHub)

### Commit
```
test: Add end-to-end barcode scanning tests

- Integration test for barcode scan → item creation flow
- All tests passing (flutter test)
- Code formatted (dart format)
- Zero warnings (flutter analyze --fatal-infos)
```

**Then:**
```
chore: Merge Stream 3A (barcode) PR to main

Includes:
- Barcode scanner widget + camera permissions
- Open Food Facts API integration + caching
- Item form pre-fill from barcode data
- Fallback manual entry
- Full test coverage (unit + widget + integration)

Closes #XX
```

---

## Day 6: Image Picker + Compression Setup

### Tasks

**T6.1: Image Picker Widget**
- [ ] Create `lib/features/attachments/ui/receipt_picker_sheet.dart`
- [ ] Camera or gallery selection (image_picker)
- [ ] Show selected image preview
- [ ] Cancel / Confirm buttons
- **Owner:** frontend-developer
- **Tests:** Widget test for picker UI

**T6.2: Image Compression Service**
- [ ] Create `lib/features/attachments/services/image_compression_service.dart`
- [ ] Compress JPEG to < 1 MB (flutter_image_compress)
- [ ] Quality trade-off: 85% quality for most images
- [ ] Test file sizes before/after
- **Owner:** backend-developer
- **Tests:**
  - Unit test: compression reduces size < 1 MB
  - Unit test: quality acceptable (visual inspection)

**T6.3: File Validation**
- [ ] Validate image format (JPEG, PNG)
- [ ] Max 10 MB input (before compression)
- [ ] Show user-friendly error messages
- **Owner:** backend-developer
- **Tests:** Unit test for validation logic

### Commit
```
feat: Image picker and compression for receipt OCR

- Created receipt_picker_sheet with camera/gallery selection
- Implemented image_compression_service (target < 1 MB)
- Added file validation (format, size)
- Widget tests for picker flow
```

---

## Day 7: Claude Vision API Client + Extraction Parsing

### Tasks

**T7.1: Claude Vision API Integration**
- [ ] Create `lib/features/attachments/services/claude_vision_service.dart`
- [ ] Base64 encode JPEG
- [ ] Send to Claude API (vision_extensions enabled)
- [ ] Parse structured JSON response
- [ ] Extract: date, amount, merchant, item_name, confidence
- **Owner:** api-architect
- **Tests:**
  - Unit test: successful extraction
  - Unit test: parsing JSON response
  - Unit test: confidence scoring

**T7.2: Vision Prompt Engineering**
- [ ] Craft extraction prompt (see spec: "Extract from receipt...")
- [ ] Test with sample receipts (various formats)
- [ ] Document prompt in code comments
- **Owner:** api-architect (with user feedback)

**T7.3: Error Handling**
- [ ] Handle 401 (auth) — check API key
- [ ] Handle 429 (rate limit) — queue + retry
- [ ] Handle image errors (invalid format)
- [ ] Log errors for debugging
- **Owner:** backend-developer
- **Tests:** Error scenario unit tests

### Subtasks
- Get Claude API key into .env.local
- Test with real receipts (photos)

### Commit
```
feat: Claude Vision API client for receipt OCR extraction

- Integrated Claude Vision API with base64 image payloads
- Implemented structured extraction prompt
- Added JSON parsing + confidence scoring
- Error handling for auth, rate limits, invalid images
- Unit tests for all scenarios
```

---

## Day 8: Extraction Review UI + User Corrections

### Tasks

**T8.1: Extraction Review Form**
- [ ] Create `lib/features/attachments/ui/extraction_review_sheet.dart`
- [ ] Display extracted fields: date, amount, merchant, item_name, confidence badges
- [ ] Editable text fields for user corrections
- [ ] Visual confidence indicators (green/yellow/red)
- [ ] "Cancel" / "Confirm & Save" buttons
- **Owner:** frontend-developer
- **Tests:** Widget test for review UI + editing

**T8.2: Field Mapping to Item Form**
- [ ] Map extraction fields → ItemFormSheet fields
- [ ] Handle date parsing (various formats)
- [ ] Handle amount parsing (currency conversion if needed)
- [ ] Save reviewed extraction + create item
- **Owner:** backend-developer
- **Tests:** Unit test for field mapping + parsing

**T8.3: Confidence Badges**
- [ ] Show confidence as percentage (e.g., "95% confident")
- [ ] Color coding: > 85% green, 50–85% yellow, < 50% red
- [ ] Warning message for low confidence: "Please review carefully"
- **Owner:** frontend-developer

### Commit
```
feat: Receipt extraction review UI with confidence indicators

- Created extraction_review_sheet with editable fields
- Implemented confidence badges (green/yellow/red)
- Added field mapping → ItemFormSheet
- Widget tests for review flow
```

---

## Day 9: Firebase Storage + RLS Enforcement + Tier Logic

### Tasks

**T9.1: Firebase Storage Attachment Saving**
- [ ] Update `AttachmentRepository.saveAttachment()`
- [ ] Check user tier: free vs. premium
- [ ] If premium: save to Firebase Storage (path: `/users/{userId}/attachments/{id}`)
- [ ] If free: save locally (Drift only)
- [ ] Generate signed URL (24-hour expiry)
- **Owner:** api-architect
- **Tests:** Unit test for tier-based storage logic

**T9.2: Storage Quota Enforcement**
- [ ] Create `lib/features/attachments/controllers/storage_quota_provider.dart`
- [ ] Fetch user quota from `storage_quotas` table
- [ ] Enforce free tier: 50 MB max OR 10 attachments
- [ ] Throw quota exception if limit reached
- **Owner:** backend-developer
- **Tests:**
  - Unit test: free tier limit enforcement
  - Unit test: premium tier unlimited

**T9.3: Tier Update Webhook**
- [ ] Setup Supabase webhook: when `profiles.subscription_tier` changes
- [ ] Auto-update `storage_quotas` tier + limits
- [ ] (Optional: Stripe webhook integration for Phase 4)
- **Owner:** api-architect
- **Tests:** Manual webhook test (curl)

### Subtasks
- Verify Firebase Storage rules deployed (should be from setup phase)
- Test signed URL generation + expiry

### Commit
```
feat: Firebase Storage + storage quota enforcement

- Wired Firebase Storage to AttachmentRepository
- Implemented tier-based storage (free: local, premium: cloud)
- Added storage quota enforcement (50 MB / 10 items for free)
- Supabase webhook for tier sync
- Unit tests for quota logic
```

---

## Day 10: Integration + Polish + Release

### Tasks

**T10.1: End-to-End Receipt Flow Test**
- [ ] Integration test: image pick → compress → Vision API → review → item created
- **Owner:** backend-developer

**T10.2: Merge Stream 3B + 3C**
- [ ] Run all tests: `flutter test`
- [ ] Code format + analyze clean
- [ ] Create PR for Streams 3B + 3C combined
- [ ] Code review + merge

**T10.3: Update README**
- [ ] Add Phase 3 section to README.md
- [ ] Link to spec + this plan
- [ ] Document new dependencies
- [ ] Update "Known limitations" with Phase 3 changes

**T10.4: Privacy Policy Draft**
- [ ] Create `docs/privacy-policy.md`
- [ ] Sections: data collection, storage, retention, user rights, GDPR/CCPA
- [ ] Mark as draft (needs legal review before app store)
- **Owner:** documentation-specialist (with user review)

**T10.5: Tag Release**
- [ ] `git tag v0.5-attachments`
- [ ] Create GitHub release with changelog
- [ ] Deploy to Firebase Hosting (web preview)

### Commit Examples

```
chore: Merge Stream 3B (receipt OCR) → main

- Claude Vision API integration for receipt extraction
- Extraction review UI with confidence badges
- Field mapping to item form
- Full test coverage

Closes #XX
```

```
chore: Merge Stream 3C (privacy + tiers) → main

- Privacy policy draft (docs/privacy-policy.md)
- Storage quota enforcement (free: 50 MB/10 items)
- Firebase Storage integration (premium only)
- Tier model in Supabase

Closes #XX
```

```
chore: Release Phase 3 v0.5-attachments

Features:
- Barcode scanning for groceries (Open Food Facts)
- Receipt OCR extraction (Claude Vision)
- Privacy policy + tiered storage (free/premium)

Breaking changes: None
Deprecations: None

Migration: Apply 0004_attachments.sql + 0005_tier_model.sql

Tests: 100% pass rate
Lint: Zero warnings (flutter analyze --fatal-infos)
```

---

## Daily Sync with Codex

**Format:** Async message in `#stayon-phase3` (or team channel)

### Template

```
[Day X] Phase 3A/3B/3C Progress

✅ Shipped today:
- T1.1 completed
- Tests passing (X/X)

🚧 In progress:
- T1.2 (75% done)

⏸ Blockers:
- None

📊 Metrics:
- Test coverage: X%
- Code review status: waiting

🔜 Next:
- T1.3 tomorrow
- PR ready for review

📎 Branch: feature/phase-3a-barcode
Commits: [link to commits]
```

### Weekly Sync (Friday)
- 30-min call: architecture Q&A, merged PRs, sprint retrospective
- Review progress vs. timeline
- Adjust scope if needed

---

## Definition of Done (Per Day)

- ✅ All code follows Dart/Flutter style guide (`dart format`)
- ✅ Zero lint warnings (`flutter analyze --fatal-infos`)
- ✅ All tests passing (`flutter test`)
- ✅ Git commits have clear messages (verb: feat/fix/test/chore/docs)
- ✅ PR created, link in daily sync to Codex
- ✅ code-reviewer proactively reviewed and approved

---

## Rollback / Pivot Points

**If barcode API unreliable:**
- Pivot to manual entry only (faster)
- Keep caching, skip Open Food Facts integration
- Re-scope to Phase 3.5

**If Claude Vision rate-limited:**
- Use on-device google_mlkit_text_recognition only
- Skip structured extraction; manual review only
- Request Claude Vision quota increase

**If Firebase Storage costs spike:**
- Default free tier to local storage only
- Reduce signed URL expiry (trade off convenience)
- Cap upload size (e.g., 5 MB instead of 10 MB)

---

## Codex Review Checkpoints

| Checkpoint | Reviewer | Action |
|-----------|----------|--------|
| Day 5 PR (Stream 3A) | code-reviewer + Codex | Approve or request changes |
| Day 10 PR (Stream 3B) | code-reviewer + Codex | Approve or request changes |
| Day 10 PR (Stream 3C) | code-reviewer + Codex | Approve or request changes |
| Release tag | Codex | Final sign-off before v0.5 |

---

**Next Step:** On Day 1, apply `0004_attachments.sql` migration and tag the user when ready.
