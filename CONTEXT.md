> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-23 — Session 15)

### Branch `main` — End-to-end audit: 19 bugs found & fixed. 0 analyze issues. All 111 tests green. Pushed to origin.

### Latest Developments (2026-07-23 — Session 15: End-to-end audit — 19 bugs fixed)

*Session 15 (comprehensive audit — 19 bugs fixed across all severity levels):*

**🔴 Critical (3):**
1. **`messages` table missing `metadata JSONB` column** — All image/voice message sends failed with PostgREST 400. Added migration `20260723000003_add_messages_metadata.sql`.
2. **`getMyApplications` and `getWorkerCompletedJobs` ordered by non-existent `created_at`** — Changed to `.order('applied_at', ...)` in both methods.
3. **`normalizePhone()` 11-digit branch silently produced invalid numbers** — Removed the broken 11-digit branch; invalid-length inputs fall through to catch-all.

**🟠 High (5):**
4. **Employer conversation visibility: chats disappeared until worker replied** — First pass now resolves worker identities from `applications` table for employer-initiated conversations.
5. **`complete_job` legacy fallback bypassed hired-state security check** — Removed unprotected legacy fallback; only the hardened RPC can complete jobs.
6. **`WorkerProfileNotifier._seeded` prevented profile refresh on account switch** — Detects user ID changes and re-seeds when the logged-in account changes.
7. **`get_nearby_workers` returned only ONE category per worker (LIMIT 1)** — Replaced with `ARRAY(SELECT ...)` returning `categories TEXT[]`; Dart handles both old and new formats.
8. **`PostJobNotifier.postJob()` reset lost default location** — Reset preserves `locationText`, `lat`, `lng` from `AppConstants`.

**🟡 Medium (6):**
9. **Employer home tab and Search tab showed identical `SearchWorkersContent`** — Employer tab now shows `EmployerDashboard` with stats and job list.
10. **Budget extraction regex matched any number (house numbers, phone numbers)** — Budget-context-aware matching: only numbers near budget keywords (rupees, price, cost, etc.).
11. **`toggleFavorite` had TOCTOU race condition on rapid double-tap** — Catches PostgREST unique violation (code 23505) and treats as success.
12. **Employer dashboard "jobs posted" undercounted (only open+completed)** — Now counts `jobs.length` (all statuses).
13. **`_HomeFeedTab` refresh listener hung on loading→data transitions** — Skips `isLoading` state in listener to avoid spinner hang.
14. **Offline message queue retried FK violations forever for deleted jobs** — Catches code 23503 (FK violation) and discards orphaned messages.

**🔵 Low (5):**
15. **`WorkerProfile.toJson()` included `is_featured` — could overwrite admin-set flag** — Removed from `toJson()`.
16. **Voice recorder platform check `!Platform.isLinux` excluded only Linux** — Changed to `!kIsWeb && (Platform.isAndroid || Platform.isIOS)` for explicit allowlist.
17. **`notifications` table had no INSERT RLS policy** — Added policy (notifications are SECURITY DEFINER-managed, but policy makes schema self-documenting).
18. **`get_nearby_workers` included null-location workers at 999999m** — Filtered to `WHERE u.current_location IS NOT NULL`.
19. **Budget extraction logic duplicated between `openrouter_service.dart` and `job_provider.dart`** — Extracted shared `lib/core/utils/budget_parser.dart` with `estimateBudget`, `guessCategory`, `guessUrgency`, `estimateDuration`.

**New Migration Files:**
| File | Description |
|------|-------------|
| `20260723000003_add_messages_metadata.sql` | Add `metadata JSONB` column to `messages` |
| `20260723000004_fix_workers_categories_notif_rls.sql` | Fix `get_nearby_workers` array categories, notifications INSERT policy, exclude null-location workers |

**New Shared Utility:**
- `lib/core/utils/budget_parser.dart` — Shared budget extraction, category guessing, urgency detection, duration estimation (used by both `openrouter_service.dart` mock fallback and `job_provider.dart` keyword parse).

**Code Health:**
- `flutter analyze`: **0 issues**
- `flutter test`: **111/111 tests pass**

### Previous Session (Session 14: End-to-end audit + 6 bug fixes)

*Session 14 (end-to-end audit — 6 bugs fixed):*

1. 🔴 **`normalizePhone()` mishandled 11-digit `92`-prefix numbers** (`auth_provider.dart`) — 11-digit numbers like `92300123456` fell through to `'+92$digits'` producing double-prefix `+9292300123456`. Fixed: handle 11-digit case by dropping the leading `92` and re-adding as country code.

2. 🟠 **`SettingsNotifier._loadSettings()` modified `localeProvider` during `build()`** (`settings_provider.dart`) — Riverpod discourages modifying another provider's state during `build()`. Fixed: wrapped `setLocale()` call in `Future.microtask()` to defer until after the build phase.

3. 🟠 **`VoiceRecorderNotifier` timer leaked on provider disposal** (`voice_recorder_provider.dart`) — The duration timer was never cancelled if the provider was disposed while recording. Fixed: added `ref.onDispose()` to cancel and null out the timer.

4. 🟡 **`JobDetailWorkerView._isInterested` always started `false`** (`job_detail_worker_view.dart`) — Workers who had already applied would see "I'm Interested" instead of "Interested ✓" on re-opening. Fixed: load existing application status from server in `initState()`.

5. 🟡 **`SupabaseRepository` used deprecated `.match()` API** (`supabase_repository.dart`) — `hireWorker()` and `toggleFavorite()` used `.match({...})` which is deprecated in supabase_flutter v2. Replaced with explicit `.eq()` chains for forward-compatibility.

6. 🟡 **`getWorkerProfile()` used `.single()` throwing on missing row** (`supabase_repository.dart`) — Replaced with `.maybeSingle()` + null check to avoid unnecessary `PostgrestException` overhead.

**Code Health:**
- `flutter analyze`: **0 issues**
- `flutter test`: **111/111 tests pass**

**🔴 Bugs Found & Fixed (8 total across Session 10 + 11):**

*Session 10 (previous):*
1. **`WorkerRepository.searchWorkers()` ignored filter parameters** — Fixed: applies PostGIS RPC for spatial filtering, `worker_categories` join for category filter.
2. **`ChatNotifier.sendMessage()` missing `isSending` toggle** — Fixed: `isSending: true` before `await`.
3. **`ChatNotifier.sendVoice()` same gap** — Fixed with same pattern.

*Session 11 (previous audit):*
4. **`getWorkerCompletedJobs()` dead filter** (`supabase_repository.dart`) — Fixed: fetch all apps + Dart filter.
5. **PostgREST `in` filter receives List instead of string** (`chat_provider.dart`) — Fixed: `.filter('id', 'in', '(...)')`.
6. **Conversation loading misses inbound messages for workers** (`chat_provider.dart`) — Fixed: also queries `applications` table.
7. **Chat list doesn't update in realtime** (`chat_provider.dart`) — Fixed: global Realtime subscription + markAsRead persistence + conversation preview.
8. **`markAsRead` marked sender's own messages as read** (`chat_provider.dart`) — Fixed: added `.filter('sender_id', 'neq', currentUserId)`.

*Session 12 (this audit):*
9. 🔴 **`WorkerRepository.generateBio()` calls wrong Edge Function** — Was calling `bright-api` (job parsing) instead of `rapid-worker` (bio/profile generation). This caused workers to get template bios based on extracted category rather than AI-generated bios. Fixed.

*Session 13 (comprehensive audit — 25 bugs fixed):*

**🔴 Critical (3):**
1. **`complete_job` RPC referenced non-existent `updated_at` columns** — Added `updated_at` to `jobs` and `applications` via new migration; also backported to `create_tables.sql`.
2. **Messages RLS policy blocked workers from reading pre-hire chat** — Replaced policy to allow any worker who has applied to a job to view messages, regardless of application status.
3. **`reports.reported_user_id` was `NOT NULL` but Settings "Report a Problem" omits it** — Made `reported_user_id` nullable in schema and migration.

**🟠 High (7):**
4. **Responsive breakpoints `tablet` and `desktop` both 840** — Set `desktop` to 1200.
5. **Coach mark overlay hole-punch rendered empty** — Replaced broken `Path.combine(reverseDifference, path, Path())` with `PathFillType.evenOdd`.
6. **Conversation list showed employer's own name when they sent the last message** — Skip employer-sent messages when resolving the "other user" for conversation previews.
7. **macOS stored `platform='ios'` for FCM tokens** — Map macOS to `'web'` (matches `fcm_tokens` CHECK constraint).
8. **"Total this week" only summed first 10 entries** — Compute total over all recent entries, display only first 10.
9. **`_jobFromApplication` used unsafe casts and wrong defaults** — Use safe `num?` casts and pass through `description`, `categoryId`, `status`, `urgency`, `budgetType`.
10. **Worker profile form state lost on async rebuild** — Preserve in-progress state after initial seed; don't overwrite on subsequent `myWorkerProfileProvider` rebuilds.

**🟡 Medium (9):**
11. **Phone normalization accepted 11-digit `92...` numbers** — Removed the 11-digit branch; only 12 digits valid.
12. **`Job.toJson()` always sent client-generated `created_at`** — Only include `created_at` when updating an existing job.
13. **"Mark All Read" performed N+1 updates** — Added `markAllNotificationsRead(userId)` batched update.
14. **Optimistic chat messages hardcoded "You"** — Added localized `AppStrings.you` and use it for optimistic text/voice messages.
15. **Offline queue sent wrong user's messages after account switch** — Tag queued messages with `queued_user_id` and discard any whose tag doesn't match the current user.
16. **`ref.read()` in `PostJobView.dispose()` could throw** — Wrapped provider read in try/catch.
17. **SMS Edge Function leaked OTP in response body** — Removed `_dev_otp` from response; log only.
18. **`match_workers_for_job` geometry/geography type mismatch** — Cast `v_job_point` to `GEOGRAPHY`.
19. **"Mark Complete" button shown for non-hired jobs** — Already correctly guarded by `job.status == JobStatus.hired`; no change needed.

**🔵 Low (6):**
20. **Workers without `current_location` were invisible in search** — Updated `get_nearby_workers` to include them with a large fallback distance.
21. **No cleanup of stale FCM tokens** — Delete older tokens for same user+platform after saving a new one.
22. **Misleading comment about applications CHECK constraint** — Updated comment to note `completed` is allowed.
23. **Duplicated `callOpenRouter` across Edge Functions** — Extracted shared `supabase/functions/_shared/openrouter.ts` and refactored `bright-api` and `rapid-worker` to import it.
24. **ID verification orphaned storage files on users update failure** — Delete uploaded verification files if the `users` table update fails.
25. **`get_nearby_jobs` returned jobs of any status** — Added `status = 'open'` filter.

**Code Health:**
- `flutter analyze`: **0 issues**
- `flutter test`: **111/111 tests pass**

**🧹 Code Health:**
- `flutter analyze`: **0 issues** (clean)
- All **134 Flutter tests pass** on Chrome
- Live Supabase integration **8/8 connection + 15/15 e2e = 23/23 all pass**
- Chat now has **dual Realtime architecture**: per-conversation `_messagesChannel` (detail view) + global `_conversationsChannel` (list previews)
- `_userJobIds` cached set enables client-side filtering on Realtime events
- All providers properly clean up channels via `ref.onDispose`
- Read receipts data path verified end-to-end: `markAsRead()` → Supabase UPDATE → `_fetchMessages()` → `Message.fromJson` → `isRead` → `done_all` icon

## Architecture

```
lib/
├── core/
│   ├── constants/app_constants.dart       # Supabase URL, keys, feature flags
│   ├── localization/
│   │   ├── strings.dart                   # 190+ bilingual AppStrings
│   │   └── locale_provider.dart           # appStringsProvider + localeProvider
│   ├── services/
│   │   ├── openrouter_service.dart        # Direct OpenRouter API calls (client-side)
│   │   ├── ai_service_provider.dart       # Riverpod provider for AI service
│   │   ├── supabase_repository.dart       # Centralized Supabase CRUD
│   │   └── notification_service.dart      # FCM init, token persistence, message handling
│   ├── utils/location_utils.dart          # GPS location + providers
│   ├── widgets/shimmer_loading.dart       # Reusable shimmer/skeleton widgets
│   └── theme/app_theme.dart               # Material 3 warm theme
├── features/
│   ├── auth/
│   │   ├── providers/auth_provider.dart   # Phone OTP Notifier + normalizePhone()
│   │   └── views/language_selection_view.dart, otp_verification_view.dart
│   ├── home/
│   │   ├── providers/role_provider.dart   # AppRole enum + currentRoleProvider
│   │   └── views/home_view.dart, employer_dashboard.dart, worker_dashboard.dart
│   ├── jobs/
│   │   ├── models/job_model.dart, providers/job_provider.dart, job_feed_provider.dart
│   │   └── views/post_job_view.dart, job_detail_view.dart, job_detail_worker_view.dart,
│   │            search_workers_view.dart, map_picker_view.dart
│   ├── chat/
│   │   ├── models/message_model.dart, providers/chat_provider.dart, voice_recorder_provider.dart
│   │   └── views/chat_detail_view.dart, chat_list_view.dart
│   ├── worker/
│   │   ├── models/worker_profile_model.dart, repositories/worker_repository.dart
│   │   ├── providers/worker_provider.dart, worker_profile_provider.dart
│   │   └── views/edit_worker_profile_view.dart, worker_public_profile_view.dart, id_verification_view.dart
│   ├── notifications/views/notifications_view.dart
│   ├── ratings/views/review_view.dart, reviews_list_view.dart
│   └── settings/
│       ├── providers/settings_provider.dart
│       └── views/settings_view.dart, reports_view.dart
test/
├── unit_tests.dart, services_test.dart, widget_test.dart, worker_dashboard_test.dart
├── supabase_connection_test.dart, e2e_flow_test.dart, ui_fixes_test.dart
├── reviews_list_view_test.dart, chat_state_test.dart
```

## Supabase (Live)

**Project ID:** `izjfugswuwyinaeauhvz` (ap-southeast-1)

**Deployed Edge Functions (4):**
| Function | Model | Purpose |
|----------|-------|---------|
| `send-sms` | Twilio Verify API | SMS hook for phone OTP (production) |
| `bright-api` | `google/gemma-4-26b-a4b-it:free` → `openrouter/free` | AI job parsing |
| `rapid-worker` | `google/gemma-4-26b-a4b-it:free` → `openrouter/free` | AI profile/bio generation |
| `send-push-notification` | FCM HTTP v1 (OAuth2) | Push notifications |

**Secrets Set:**
- `SMS_PROVIDER=twilio` (production — real SMS via Twilio Verify)
- `OPENROUTER_API_KEY=<set>` (OpenRouter API key for AI model access)
- `FCM_SERVICE_ACCOUNT=<set>` (Firebase service account JSON for FCM v1)

**AI 3-Tier Fallback Chain:**
1. **Tier 1 (primary):** Edge Function → OpenRouter `google/gemma-4-26b-a4b-it:free` → fallback `openrouter/free` auto-router
2. **Tier 2 (client):** Flutter `OpenRouterService` → same models via `.env` key
3. **Tier 3 (always works):** Keyword-based mock parsing in Dart/TypeScript

**Database Tables (13):**
`users`, `categories` (31 bilingual), `worker_profiles`, `worker_categories`, `jobs` (with PostGIS), `applications`, `messages`, `reviews`, `notifications`, `favorites`, `reports`, `fcm_tokens`, `user_settings`

**Storage Buckets (3):** `chat_images` (public), `verification_docs` (private), `voice_messages` (public)

**PostGIS RPC Functions:** `get_nearby_jobs`, `get_nearby_workers`, `match_workers_for_job`, `get_user_fcm_token`

**Database Webhooks (3 triggers deployed):**
- `trg_notify_on_message_insert` on `messages` AFTER INSERT
- `trg_notify_on_job_insert` on `jobs` AFTER INSERT
- `trg_notify_on_application_insert` on `applications` AFTER INSERT

**Migrations Applied:**
| File | Description |
|------|-------------|
| `20260718000000_create_tables.sql` | Core schema: tables, RLS, categories, PostGIS RPCs |
| `20260719000001_add_favorites_reports.sql` | Favorites + reports tables |
| `20260720000001_worker_profile_insert_policy.sql` | Worker profile insert policy |
| `20260720000002_worker_profile_rpc_and_categories_policy.sql` | Worker profile RPC + categories policy |
| `20260720000003_auth_users_trigger.sql` | Auto-create public.users on auth.users insert |
| `20260721000001_add_user_settings.sql` | User settings columns |
| `20260722000001_smart_matching_function.sql` | Weighted worker-job matching RPC |
| `20260722000002_add_fcm_tokens.sql` | FCM tokens table + get_user_fcm_token RPC |
| `20260722000003_add_verification_columns.sql` | ID verification columns on users table |
| `20260722000004_storage_rls_policies.sql` | Storage bucket RLS policies |
| `20260722000005_delete_user_data_rpc.sql` | Account deletion RPC function |
| `20260722000006_add_rls_delete_policies.sql` | DELETE policies for data cleanup |
| **`20260722000007_database_webhooks.sql`** | Push notification trigger functions (3 triggers) |
| **`20260722000008_fix_job_trigger_column.sql`** | Fix `wp.user_id` → `wp.id` in job trigger |

## What's Implemented (20 features)

1. ✅ Onboarding / Auth (language + phone OTP)
2. ✅ Home Feed (Worker) — live jobs via Realtime, skeleton loaders
3. ✅ Home Feed (Employer) — welcome card + quick actions (role-aware feed)
4. ✅ Post a Job — AI parsing with 3-tier fallback, map picker (OpenStreetMap)
5. ✅ Job Detail (Employer view) — applicants list, hire flow, mark complete
6. ✅ Job Detail (Worker view) — I'm Interested, chat access
7. ✅ Worker Profile (edit) — AI bio generation, portfolio, availability
8. ✅ Worker Profile (public view) — read-only with reviews, favorite, hire
9. ✅ ID Verification — upload CNIC + selfie to Supabase Storage
10. ✅ Chat — realtime, image/voice/location, typing indicator, read receipts, offline queue
11. ✅ Search/Browse Workers — filters, skeleton loaders
12. ✅ Ratings & Review — two-way star rating with animation
13. ✅ Notifications screen — live list, filter by type
14. ✅ Employer Dashboard — live jobs + applicant counts
15. ✅ Worker Dashboard — live stats, applications, earnings, availability toggle
16. ✅ Settings — language, notifications, radius, verification, logout, delete account
17. ✅ Favorites View — saved workers list with remove
18. ✅ Reports View — submitted reports list + new report dialog
19. ✅ Reviews List View — All/Given/Received tabs, pull-to-refresh
20. ✅ **Database Webhooks** — Auto-trigger push notifications on messages/jobs/applications INSERT

## Test Suite (134 Flutter + 13 Deno Edge Function)

### Flutter Tests (134 total, all pass)
| Category | Tests | Files |
|----------|-------|-------|
| **Unit tests** | 73+ | `unit_tests.dart`, `services_test.dart`, `chat_state_test.dart` |
| **Widget/UI** | 35 | `widget_test.dart`, `worker_dashboard_test.dart`, `reviews_list_view_test.dart`, `ui_fixes_test.dart` |
| **Integration** | 23 | `supabase_connection_test.dart`, `e2e_flow_test.dart` |

### Edge Function Tests (13 Deno tests, 12 pass)
| File | Tests | Status |
|------|-------|--------|
| `send-sms/index_test.ts` | 2 | ✅ All pass |
| `bright-api/index_test.ts` | 4 | ✅ All pass |
| `rapid-worker/index_test.ts` | 2 | ✅ All pass |
| `send-push-notification/index_test.ts` | 5 | ✅ All pass |

## Future Goals / Phase 2 Roadmap

### Short-term (Next Sprint)
- [ ] **Map/list toggle on Worker Feed** — The prompt requires a list/map toggle on the home feed to view nearby jobs on a map
- [ ] **Push notifications end-to-end verification** — Test FCM delivery on a physical Android device (trigger exists, needs a worker with FCM token)
- [x] **Push to origin** — ✅ Pushed commit `d3bb214` to `origin/main` (16 files, 19 bug fixes + 2 migrations deployed)

### Medium-term
- [x] **Push notification webhooks** — ✅ Deployed 3 triggers + fix migration. Tested with real job INSERT.
- [ ] **Unread notification badge** — Badge count on the bell icon in AppBar
- [ ] **Voice/video calling** (real WebRTC, not snackbar placeholder)

### Phase 3 (Future)
- [ ] **Payments / Escrow** — JazzCash/Easypaisa integration via Edge Function (data model ready for `escrow`/`transactions` table)
- [ ] **AI fraud detection** — Automated report triage, auto-suspend thresholds
- [ ] **Enterprise/business accounts** — Multi-location employers, analytics dashboards
- [ ] **Recurring/scheduled subscriptions** — For regular service bookings
