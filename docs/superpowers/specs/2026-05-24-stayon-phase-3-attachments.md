# Phase 3 Spec: Attachments + Image Processing (v0.5-attachments)

**Status:** DRAFT | **Last Updated:** 2026-05-24 | **Target Release:** Week 7

---

## Overview

Phase 3 adds image attachment and AI-powered extraction to StayOn, enabling users to:
- **Scan barcodes** of groceries → auto-populate item details
- **Upload receipt/warranty photos** → extract dates, amounts, serial numbers via OCR
- **Manage storage** with free/premium tiers (50MB free, unlimited premium)

### Goals
- ✅ Reduce manual item entry friction (barcode scan vs. typing)
- ✅ Auto-extract key details from receipt photos (dates, vendors, amounts)
- ✅ Support both on-device and cloud-based processing
- ✅ Prepare privacy/compliance for App Store submission

### Non-Goals (Phase 4+)
- Real-time collaborative editing
- AI-powered category suggestions (Phase 4)
- Smart expiry prediction from receipt dates (Phase 4)

---

## Architecture Overview

### Three Parallel Streams

```
┌─ Stream 3A: Barcode Scanning ─────────┐
│ Mobile → Camera → ML Kit → Open Food  │
│ Facts → Fallback UI → Item Form       │
└──────────────────────────────────────┘

┌─ Stream 3B: Receipt OCR ──────────────┐
│ Image Picker → Compress → Claude      │
│ Vision API → Parse → Review UI →      │
│ Item Form                             │
└──────────────────────────────────────┘

┌─ Stream 3C: Privacy + Tiers ──────────┐
│ Privacy Policy → RLS Rules →          │
│ Storage Quota UI → Tier Model         │
└──────────────────────────────────────┘
```

### Data Flow

```
User Intent
    ↓
┌─ Barcode: Camera → ML Kit Barcode Scanner
└─ Receipt: Image Picker → Compression
    ↓
┌─ Barcode: Open Food Facts HTTP
└─ Receipt: Claude Vision API (base64 JPEG)
    ↓
Parse Response (JSON or structured text)
    ↓
Review UI (user verifies extracted fields)
    ↓
Create/Update Item (add attachment metadata)
    ↓
Local Cache (Drift) → Supabase sync → Firebase Storage
```

---

## Data Models

### Supabase Schema (New Tables)

#### `0004_attachments.sql` — Create tables

```sql
-- Attachment metadata
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  
  -- File metadata
  filename text not null,
  content_type text not null, -- image/jpeg, application/pdf, etc.
  file_size_bytes int not null,
  
  -- Storage location
  storage_path text not null, -- gs://bucket/users/{owner_id}/attachments/{id}
  storage_tier text not null default 'local', -- 'local' | 'cloud'
  
  -- Extraction metadata
  extraction_type text, -- 'barcode' | 'receipt' | 'warranty' | null
  extraction_data jsonb, -- Structured extracted fields
  extraction_confidence float, -- 0.0–1.0 for OCR
  extraction_reviewed_at timestamp,
  
  -- Timestamps
  created_at timestamp not null default now(),
  updated_at timestamp not null default now(),
  
  constraint filename_not_empty check (filename != ''),
  constraint valid_tier check (storage_tier in ('local', 'cloud')),
  constraint valid_type check (content_type in (
    'image/jpeg', 'image/png', 'application/pdf'
  ))
);

create index attachments_owner_id_idx on public.attachments(owner_id);
create index attachments_item_id_idx on public.attachments(item_id);

-- RLS Policies
alter table public.attachments enable row level security;

create policy "attachments_select_own"
  on public.attachments for select
  using (auth.uid() = owner_id);

create policy "attachments_insert_own"
  on public.attachments for insert
  with check (auth.uid() = owner_id);

create policy "attachments_update_own"
  on public.attachments for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "attachments_delete_own"
  on public.attachments for delete
  using (auth.uid() = owner_id);

-- Storage quota tracking
create table public.storage_quotas (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'free', -- 'free' | 'premium'
  total_bytes_used int not null default 0,
  quota_limit_bytes int not null default 52428800, -- 50 MB for free
  attachment_count int not null default 0,
  attachment_limit int not null default 10, -- 10 items for free
  updated_at timestamp not null default now()
);

alter table public.storage_quotas enable row level security;

create policy "storage_quotas_select_own"
  on public.storage_quotas for select
  using (auth.uid() = owner_id);
```

#### `0005_tier_model.sql` — Add tier to profiles

```sql
-- Add subscription tier to profiles
alter table public.profiles
  add column subscription_tier text default 'free' not null,
  add constraint valid_subscription_tier 
    check (subscription_tier in ('free', 'premium'));

-- Add storage tier preference
alter table public.profiles
  add column prefer_cloud_storage boolean default false;
```

### Dart Models

#### `lib/core/models/attachment.dart`

```dart
@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    required String ownerId,
    required String itemId,
    required String filename,
    required String contentType,
    required int fileSizeBytes,
    required String storagePath,
    required String storageTier, // 'local' | 'cloud'
    required String? extractionType, // 'barcode' | 'receipt' | 'warranty'
    required Map<String, dynamic>? extractionData,
    required double? extractionConfidence,
    required DateTime? extractionReviewedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Attachment;
}

@freezed
class ExtractionResult with _$ExtractionResult {
  const factory ExtractionResult({
    required String type, // barcode | receipt
    required Map<String, dynamic> data,
    required double confidence,
    required List<String> warnings,
  }) = _ExtractionResult;
}

@freezed
class StorageQuota with _$StorageQuota {
  const factory StorageQuota({
    required String ownerUserId,
    required String tier,
    required int totalBytesUsed,
    required int quotaLimitBytes,
    required int attachmentCount,
    required int attachmentLimit,
    required DateTime updatedAt,
  }) = _StorageQuota;

  String get usagePercent => totalBytesUsed * 100 ~/ quotaLimitBytes;
  bool get isAtCapacity => usagePercent >= 100;
  bool get nearCapacity => usagePercent >= 80;
}
```

---

## Stream 3A: Barcode Scanning

### Feature Breakdown

**T1: Barcode Scanner Widget**
- Camera permission request + fallback (ask to enable in Settings)
- Live preview with scanner overlay
- Audio/haptic feedback on successful scan
- Tests: camera permission flow, barcode detection signal

**T2: Open Food Facts Integration**
- HTTP client wrapper (with retry logic)
- Barcode → product lookup → return name, brand, estimated expiry
- Fallback: show "Barcode not found" + manual entry option
- Cache: Drift `cached_products` table (offline resilience)
- Tests: API client, cache hit/miss, retry exponential backoff

**T3: Fallback Manual Entry**
- If barcode lookup fails, user can type name manually
- Pre-populate with barcode number for reference
- Wire to existing Item form

**T4: Wire to Item Form**
- Barcode scan → populate name + category suggestion
- User edits/confirms → save to items table
- Attachment record created (type: 'barcode')

### Open Food Facts Schema

```json
{
  "code": "5901012016015",
  "product": {
    "product_name": "Lactose-free milk",
    "brands": "Arla Foods",
    "packaging": "Cardboard carton, plastic bottle",
    "expiration_date": "2026-06-24",
    "generic_name": "Milk"
  }
}
```

### Extracted Item Fields

```
Name: "Lactose-free milk (Arla Foods)"
Category: Groceries (inferred)
Target Date: 2026-06-24 (expiration_date from API)
Date Type: Expires
Attachment: { type: "barcode", extraction_data: { code, product_name, ... } }
```

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Camera permission denied | Show sheet: "Enable camera in Settings" → link to app settings |
| Barcode not recognized | Show "Barcode not found" → manual name entry |
| Network error (no Open Food Facts) | Cached barcode or manual fallback |
| Malformed response | Log error; show "Could not fetch product info" |

---

## Stream 3B: Receipt OCR

### Feature Breakdown

**T5: Image Picker Widget**
- Camera or gallery selection
- Automatic compression (< 1 MB JPEG)
- Tests: picker integration, compression validation

**T6: Claude Vision API Integration**
- Base64 encode JPEG → send to Claude Vision
- Structured prompt: extract date, amount, merchant, item names
- Confidence scoring (0.0–1.0)
- Tests: Vision API client, confidence thresholds, structured output parsing

**T7: User Review Flow**
- Display extracted fields in editable form
- User reviews + corrects before save
- Show confidence indicators (green/yellow/red)
- Tests: extraction review UI, field editing, save validation

**T8: Wire to Item Form**
- Receipt OCR → populate multiple item fields
- If multiple items detected → split into separate items
- Store extraction metadata + original image

### Claude Vision Prompt

```
Extract the following information from this receipt/warranty:
- Date (invoice or warranty effective date)
- Amount (total cost, if visible)
- Merchant name
- Item name / description
- Serial number or warranty code
- Any expiry/warranty end date

Return JSON:
{
  "date": "YYYY-MM-DD",
  "amount_minor": 50000,
  "merchant": "Best Buy",
  "item_name": "Samsung Galaxy Watch 6",
  "serial_number": "ABC123XYZ",
  "warranty_end_date": "2028-05-24",
  "warnings": ["date unclear", "amount partially obscured"]
}

Confidence: 0.0–1.0
```

### Storage Strategy

- Local device: Drift `attachment_cache` (recent extractions)
- Cloud (premium only): Firebase Storage + Supabase metadata
- Signed URLs: 24-hour expiry (security)

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Image > 10 MB | Compress automatically; show "Compressed to XMB" |
| Invalid image format | Show "Only JPEG/PNG/PDF supported" |
| Vision API rate limit | Queue + retry with exponential backoff |
| Extraction confidence < 50% | Mark fields as "needs review"; warn user |

---

## Stream 3C: Privacy + Storage Tiers

### Privacy Policy

**Location:** `docs/privacy-policy.md` (draft by assistant, reviewed by user)

**Key sections:**
- What data we collect (photos, extracted fields)
- Where it's stored (local device by default; cloud if premium)
- How long it's retained (30 days after deletion)
- User rights (download, delete, export)
- GDPR/CCPA compliance notes

### Storage Tiers

#### Free Tier (Default)
- Storage: 50 MB max OR 10 attachments max (whichever hit first)
- Location: Local device (Drift) only
- Sync: Manual (no cloud backup)
- Features: Barcode scan + OCR (on-device)

#### Premium Tier
- Storage: Unlimited
- Location: Firebase Storage + Supabase
- Sync: Automatic (real-time)
- Features: All + sync across devices (Phase 4)

### Quota Enforcement

```dart
// In AttachmentRepository
Future<void> saveAttachment(Attachment att, Uint8List bytes) async {
  final quota = await fetchUserQuota();
  
  // Check free tier limits
  if (quota.tier == 'free') {
    if (quota.attachmentCount >= 10) {
      throw QuotaException('Max 10 attachments on free tier');
    }
    if (quota.totalBytesUsed + bytes.length > 52428800) {
      throw QuotaException('Max 50 MB on free tier');
    }
  }
  
  // Save locally (Drift)
  await drift.attachmentDao.insert(att);
  
  // Save to cloud if premium
  if (quota.tier == 'premium') {
    await firebase.storage.saveAttachment(att, bytes);
    await supabase.updateStorageQuota(quota.copyWith(
      totalBytesUsed: quota.totalBytesUsed + bytes.length,
      attachmentCount: quota.attachmentCount + 1,
    ));
  }
}
```

### UI Indicators

- Storage usage bar (Settings screen)
- "Upgrade to Premium" CTA when near limit
- Badge on tabs (e.g., "10/10 attachments")

---

## Testing Strategy

### Unit Tests (TDD)
- Barcode API client (mock Open Food Facts, test retry logic)
- Claude Vision client (mock Vision API, test extraction parsing)
- Storage quota logic (free tier limits, upgrades)
- Drift migrations (schema integrity)

### Widget Tests
- Barcode scanner overlay + buttons
- Image picker UI flow
- Extraction review form
- Storage quota display

### Integration Tests
- Camera permission flow end-to-end
- Barcode scan → item creation
- Receipt upload → extraction → item creation
- Storage quota enforcement (free tier hitting limit)

### Manual Testing (with 2-3 beta users)
- Real barcodes (groceries, items)
- Real receipts (various lighting, angles)
- Network errors (flight mode toggle)
- Storage limit scenarios

### Metrics to Track
- Barcode recognition accuracy (target: > 95%)
- OCR extraction confidence (target: avg > 0.85)
- API latency (barcode: < 500ms; OCR: < 2s)
- Storage quota hit rate (track when users upgrade)

---

## Deployment Pipeline

### Week 1–2: Stream 3A (Barcode)
1. Migrations: `0004_attachments.sql`
2. Dart models + migrations
3. Barcode widget + Open Food Facts client
4. Drift cache + tests
5. PR → code-reviewer → merge

### Week 2–3: Stream 3B (OCR)
1. Image picker + compression
2. Claude Vision client + tests
3. Extraction review UI
4. Firebase Storage setup
5. PR → code-reviewer → merge

### Week 3: Stream 3C (Privacy + Tiers)
1. Privacy policy draft
2. Supabase migrations: `0005_tier_model.sql`
3. Quota enforcement logic
4. UI indicators (Settings)
5. PR → code-reviewer → merge

### Week 4–5: Integration + Polish
1. Wire all streams together
2. End-to-end tests
3. Beta user feedback incorporation
4. Performance profiling

### Week 6–7: Release
1. Final code review (code-reviewer + Codex)
2. Deploy v0.5-attachments tag
3. Firebase Hosting + web preview
4. GA notification

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Barcode accuracy < 95% | Fallback manual entry always available; user research on common barcodes |
| API rate limits (Open Food Facts, Claude Vision) | Queue system + exponential backoff; cache responses |
| User storage quota hits | Proactive warnings at 80%; clear upgrade CTA; delete old attachments UI |
| Image corruption (lossy compression) | Test with various image sources; user warning before compression |
| Privacy compliance | Legal review of privacy policy; GDPR deletion hooks |
| Firebase cost spikes | Monitor storage usage; set billing alerts; free tier defaults to local |

---

## Success Criteria

- ✅ Barcode scan < 3s end-to-end (camera open → result)
- ✅ Receipt OCR extraction confidence avg > 0.85
- ✅ Free tier storage limit enforced (50 MB / 10 items)
- ✅ 2–3 beta users testing; feedback documented
- ✅ All tests pass; `flutter analyze` clean
- ✅ Privacy policy live
- ✅ 0 critical bugs in release candidate

---

## Appendix: API Contracts

### Open Food Facts
- **Endpoint:** `GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json`
- **Response:** Product object with product_name, brands, expiration_date, generic_name
- **Errors:** 404 (not found); 429 (rate limit); 5xx (server)

### Claude Vision API
- **Endpoint:** Anthropic Claude API (vision_extensions enabled)
- **Payload:** base64 JPEG + structured extraction prompt
- **Response:** JSON with date, amount, merchant, item_name, confidence
- **Errors:** 429 (rate limit); 401 (auth); invalid image format

### Firebase Storage
- **Bucket:** `stayon-c6ead.appspot.com`
- **Path:** `/users/{userId}/attachments/{attachmentId}`
- **Rules:** RLS-enforced (10 MB per file; images + PDF only)
- **Signed URLs:** 24-hour expiry

---

**Next:** See `/docs/superpowers/plans/2026-05-24-stayon-phase-3-tasks.md` for granular 2-week sprint breakdown.
