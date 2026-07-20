# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-20)

### Branch `main` — MVP complete, screens now wired to live Supabase data. Local commits ahead of `origin/main` (not yet pushed).

**Status:** Builds clean (`dart analyze` → 0 errors). Tests run on **Chrome only**
(`flutter test --platform=chrome`; native Linux fails — `google_maps_flutter` /
`firebase_messaging` have no Linux desktop build). All committed work is green.

**Recent work (commit `7beacba`, unpushed):** migrated to **supabase_flutter v2**
(`Supabase.initialize(publishableKey:)` instead of `anonKey:`) and replaced mock
UI with live Supabase-backed screens — notably the **employer dashboard** (live
jobs + applicant counts via new `countApplicants`/`getApplicants`), **settings**
(real `authProvider.signOut()` logout), and converted `job_detail`,
`notifications`, `search_workers`, `worker_public_profile` to `Consumer` widgets.
Chat provider now fully tears down realtime channels (`unsubscribe` + `removeChannel`).

## Architecture

```
lib/
├── core/
│   ├── constants/app_constants.dart     # Supabase URL, keys, feature flags
│   ├── localization/                    # strings.dart, locale_provider.dart
│   ├── services/
│   │   ├── openrouter_service.dart      # Direct OpenRouter API calls (client-side)
│   │   └── ai_service_provider.dart     # Riverpod provider for AI service
│   ├── services/supabase_repository.dart # Centralized Supabase CRUD
│   └── theme/app_theme.dart             # Material 3 warm theme
├── features/
│   ├── auth/
│   │   ├── providers/auth_provider.dart # Phone OTP Notifier + normalizePhone()
│   │   ├── views/language_selection_view.dart
│   │   └── views/otp_verification_view.dart
│   ├── home/views/home_view.dart        # Tab bar: Feed, Search, Post, Chat, Dashboard
│   ├── jobs/
│   │   ├── models/job_model.dart        # Job class with PostGIS location_coords
│   │   ├── providers/job_provider.dart   # PostJobNotifier with 3-tier AI fallback
│   │   ├── providers/job_feed_provider.dart # Live job stream via Realtime
│   │   ├── repositories/job_repository.dart
│   │   └── views/post_job_view.dart
│   ├── chat/
│   │   ├── models/message_model.dart
│   │   ├── providers/chat_provider.dart  # Realtime chat with onPostgresChanges
│   │   ├── repositories/chat_repository.dart
│   │   ├── views/chat_detail_view.dart
│   │   └── views/chat_list_view.dart
│   ├── worker/                          # Profile, public profile, dashboard
│   ├── notifications/                   # Notifications view
│   └── settings/                        # Settings view
test/
├── widget_test.dart                     # 21 widget UI tests
├── supabase_connection_test.dart        # 8 Supabase live connection tests
└── e2e_flow_test.dart                   # 15 schema validation tests (renumbered)
```

## Supabase (Live)

**Project ID:** `izjfugswuwyinaeauhvz` (ap-southeast-1)

**Deployed Edge Functions:**
| Function | Purpose | Endpoint |
|----------|---------|----------|
| `send-sms` | SMS hook for phone OTP | `/functions/v1/send-sms` |
| `bright-api` | OpenRouter proxy for AI job parsing | `/functions/v1/bright-api` |

**Secrets Set:**
- `SMS_PROVIDER=log` (dev mode — logs OTP instead of sending SMS)
- `OPENROUTER_API_KEY=<set>` (free OpenRouter key for AI parsing)

**Database Tables (11):**
`users`, `categories` (31 bilingual), `worker_profiles`, `worker_categories`, `jobs` (with PostGIS), `applications`, `messages`, `reviews`, `notifications`, `favorites`, `reports`

**PostGIS RPC Functions:** `get_nearby_jobs`, `get_nearby_workers`

**Auth:** Phone OTP enabled, SMS hook configured, email signup also enabled

## Key Architecture Decisions

### State Management
- **Riverpod v3** throughout (manual providers, no codegen). `Notifier` for mutable state (auth, chat, job posting). `StreamProvider` for live data (job feed). `Provider` for singletons (AI service).

### Supabase SDK — v2 API
- Package `supabase_flutter: ^2.16.0`. `Supabase.initialize(url:, publishableKey:)` (the v1 `anonKey:` param is gone).
- **Test-safety rule:** `Supabase.instance.client` throws an `AssertionError` when `Supabase.initialize()` has not run. Widget tests do NOT initialize Supabase, so any provider built during a test must guard that access. The established pattern (see `auth_provider.dart`, `job_feed_provider.dart`): wrap the access in `try { … } catch (_) { return null / empty; }`. `currentUserProvider` and `supabaseClientProvider` (now `Provider<SupabaseClient?>`) return null when uninitialized; `liveJobFeedProvider` emits an empty list via a `StreamController` on catch (`Stream.empty()` / `Stream.value([])` leave `StreamProvider` stuck in `AsyncLoading` under Riverpod 3 — emit `[]` then close the controller). `workerRepositoryProvider` is nullable with short-circuiting callers. Production is unaffected: `main()` always initializes Supabase before building UI. Symptom of a missing guard: a `pumpAndSettle` test hangs on a perpetual `CircularProgressIndicator`, or throws `ProviderException: Tried to use a provider that is in error state`.

### Realtime Subscriptions
- **Job Feed:** `liveJobFeedProvider` = `StreamProvider` using `supabase.from('jobs').stream(primaryKey: ['id'])`
- **Chat:** `ChatNotifier` uses `onPostgresChanges` on `messages` table for live updates
- Both auto-refresh on INSERT/UPDATE/DELETE from any client

### AI Integration (OpenRouter Free Models)
- **Tier 1:** Edge Function `bright-api` → OpenRouter `mistralai/mistral-7b-instruct:free`
- **Tier 2:** Direct Flutter → OpenRouter (same models, client-side fallback)
- **Tier 3:** Keyword-based mock parsing (always works, no API needed)
- **Cost control:** Results cached in `PostJobState.parsedResult` until user edits freeform text

### Phone OTP Flow
1. LanguageSelectionView → enters phone → calls `AuthNotifier.sendOtp()`
2. Supabase Auth generates OTP → calls SMS hook Edge Function
3. Edge Function logs OTP (dev) or sends real SMS (prod)
4. OTP verification view → calls `AuthNotifier.verifyOtp()`
5. Success → `authStateChangesProvider` triggers navigation to HomeView

### PostGIS Geography
- Database stores location as `location_coords GEOGRAPHY(POINT, 4326)`
- `Job._parseCoordinates()` handles 3 formats: GeoJSON (PostgREST default), WKT ("POINT(lng lat)"), legacy columns
- `Job.toJson()` outputs `'location_coords': 'POINT(lng lat)'`

## What's Implemented (15 Screens)
1. ✅ Onboarding / Auth (language + phone OTP)
2. ✅ Home Feed (Worker) — live jobs via Realtime
3. ✅ Home Feed (Employer) — welcome card + quick actions
4. ✅ Post a Job — AI parsing with 3-tier fallback
5. ✅ Job Detail (Employer view) — wired to live job data + chat
6. ✅ Job Detail (Worker view) — wired to live job data + apply flow
7. ✅ Worker Profile (edit) — AI bio generation button
8. ✅ Worker Profile (public view) — read-only with reviews + favorite
9. ✅ Chat — realtime with message streaming (channel fully torn down on exit)
10. ✅ Search/Browse Workers — live worker feed
11. ✅ Ratings & Review — mutual review flow
12. ✅ Notifications screen — live notification list
13. ✅ Employer Dashboard — **live jobs + applicant counts** (no longer mock stats)
14. ✅ Worker Dashboard
15. ✅ Settings — language, account, **real logout via `authProvider.signOut()`**

## Test Suite (44 tests)
> Run on Chrome: `export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable && flutter test --platform=chrome`
- `test/widget_test.dart` — **21** widget/UI tests (run without network; Supabase is NOT initialized, so providers must be test-guarded — see above)
- `test/supabase_connection_test.dart` — **8** live Supabase connection tests (require network + anon key)
- `test/e2e_flow_test.dart` — **15** schema-validation tests (require network)
- `flutter test --platform=chrome` runs widget + connection tests (23). The 15 schema tests are in `e2e_flow_test.dart`.

## Open Tasks / Remaining Gaps
- [ ] **Unpushed local commits:** `main` is ahead of `origin/main` by 3 commits
      (`7beacba`, `cba69b6`, `c1f54c3`). Push when ready.
- [ ] **AI Profile Generation:** Create `rapid-worker` Edge Function (similar to `bright-api` but for worker bios)
- [ ] **Push Notifications:** Wire up FCM with Supabase Edge Function triggers
- [ ] **Google Maps:** API key placeholder — need real key for map picker
- [ ] **Location Schema Alignment:** `location_lat`/`lng` still sent in `PostJobNotifier.postJob()` alongside `location_coords` (needs cleanup in some spots)
- [ ] **Favorites/Reports UI:** Tables exist but views don't use them yet
- [ ] **Missing tables:** No `escrow`/`transactions` table yet (Phase 3)
- [ ] **Desktop build:** `flutter create --platforms=linux` done but CMake/Ninja not available
- [ ] **Chrome install:** Needed for web-based testing

