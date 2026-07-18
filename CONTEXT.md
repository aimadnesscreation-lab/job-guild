# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (July 2026)

### Branch: MVP Complete — screens navigable, Supabase live, 36 tests passing

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
- **Riverpod v3** throughout. `Notifier` for mutable state (auth, chat, job posting). `StreamProvider` for live data (job feed). `Provider` for singletons (AI service).

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
5. ✅ Job Detail (Employer view) — placeholder
6. ✅ Job Detail (Worker view) — placeholder
7. ✅ Worker Profile (edit) — AI bio generation button
8. ✅ Worker Profile (public view) — read-only with reviews
9. ✅ Chat — realtime with message streaming
10. ✅ Search/Browse Workers
11. ✅ Ratings & Review — mutual review flow
12. ✅ Notifications screen
13. ✅ Employer Dashboard
14. ✅ Worker Dashboard
15. ✅ Settings — language, account, logout

## Test Suite (36 tests)
- `flutter test` runs all 36 tests
- `flutter test test/supabase_connection_test.dart` — live Supabase connectivity
- `flutter test test/e2e_flow_test.dart` — schema validation (all 11 tables)

## Open Tasks / Remaining Gaps
- [ ] **AI Profile Generation:** Create `rapid-worker` Edge Function (similar to `bright-api` but for worker bios)
- [ ] **Push Notifications:** Wire up FCM with Supabase Edge Function triggers
- [ ] **Google Maps:** API key placeholder — need real key for map picker
- [ ] **Location Schema Alignment:** `location_lat`/`lng` still sent in `PostJobNotifier.postJob()` alongside `location_coords` (needs cleanup in some spots)
- [ ] **Favorites/Reports UI:** Tables exist but views don't use them yet
- [ ] **Missing tables:** No `escrow`/`transactions` table yet (Phase 3)
- [ ] **Desktop build:** `flutter create --platforms=linux` done but CMake/Ninja not available
- [ ] **Chrome install:** Needed for web-based testing
