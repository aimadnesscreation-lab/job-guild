> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-22 — Session 12)

### Branch `main` — Session 12 audit: 9th bug found & fixed. 0 analyze issues. All 134 tests green.

**Status:** Flutter tests **134/134** pass. **0 dart analyze issues**. Live Supabase integration **23/23** pass. Local commits ahead of `origin/main` (not yet pushed).

### Latest Developments (2026-07-22 — Session 12: End-to-end codebase audit)

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
9. 🔴 **`WorkerRepository.generateBio()` calls wrong Edge Function** — Was calling `bright-api` (job parsing) instead of `rapid-worker` (bio/profile generation). This caused workers to get template bios based on extracted category rather than AI-generated bios. Fixed:
   - Changed function name from `bright-api` → `rapid-worker`
   - Changed body key from `description` → `raw_description` (matching `rapid-worker`'s `ProfileRequestBody`)
   - Changed response parsing from extracting `category` to extracting `bio` directly (now returns the actual AI-generated bio)

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
| `send-push-notification/index_test.ts` | 5 | ⚠️ 4 pass, 1 needs `--allow-net` |

## Future Goals / Phase 2 Roadmap

### Short-term (Next Sprint)
- [ ] **Map/list toggle on Worker Feed** — The prompt requires a list/map toggle on the home feed to view nearby jobs on a map
- [ ] **Push notifications end-to-end verification** — Test FCM delivery on a physical Android device (trigger exists, needs a worker with FCM token)
- [ ] **Push to origin** — Get local commits backed up to GitHub

### Medium-term
- [x] **Push notification webhooks** — ✅ Deployed 3 triggers + fix migration. Tested with real job INSERT.
- [ ] **Unread notification badge** — Badge count on the bell icon in AppBar
- [ ] **Voice/video calling** (real WebRTC, not snackbar placeholder)

### Phase 3 (Future)
- [ ] **Payments / Escrow** — JazzCash/Easypaisa integration via Edge Function (data model ready for `escrow`/`transactions` table)
- [ ] **AI fraud detection** — Automated report triage, auto-suspend thresholds
- [ ] **Enterprise/business accounts** — Multi-location employers, analytics dashboards
- [ ] **Recurring/scheduled subscriptions** — For regular service bookings
