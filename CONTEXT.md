> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-30 — Session 40: 4-Phase Bug Remediation — 17 Fixes)

### Session 40: 4-Phase Bug Remediation — 17 Bugs Fixed Across 14 Files

*Session 40 (systematic 4-phase bug fix sweep from audit):*

**Phase 1 — Critical Fixes (3 bugs):**
1. **🔴 BUG-40-01 — Chat `_parseJobIds` key mismatch** — `applications` table uses `job_id` column, but `_parseJobIds` was hardcoded to read `id`. Workers never saw employer-initiated conversations. **Fix:** Added `{String key = 'id'}` parameter, called with `key: 'job_id'` for applications.
2. **🔴 BUG-40-02 — `dart:io` import blocking web compilation** — `auth_provider.dart` imported `dart:io` and used `on SocketException` catches, which are unavailable on web. **Fix:** Removed `dart:io` import, replaced all 4 `SocketException` catches with `on Exception catch (e)` + string-matching pattern.
3. **🔴 BUG-40-03 — RPC column name `availability` vs `availability_status`** — Migration aliased `availability_status as availability`, but `WorkerProfile.fromJson` expects `availability_status`. All workers showed as 'offline'. **Fix:** Removed alias in migration, updated `search_workers_view.dart` to read `availability_status`.

**Phase 2 — High Severity (4 bugs):**
4. **🔴 BUG-40-04 — NULL-location workers in nearby results** — Migration had `WHERE u.current_location IS NULL OR st_dwithin(...)`, including workers without location. **Fix:** Changed to `IS NOT NULL AND`.
5. **🔴 BUG-40-05 — Non-atomic `hireWorker`** — Two-step client-side update could leave application & job in inconsistent states. **Fix:** Created `hire_worker` SECURITY DEFINER RPC (new migration `20260730000000`) + updated Dart repo to use atomic RPC.
6. **🔴 BUG-40-06 — Null ID in offline queue retry** — Retry inserted `msg['id'] as String?` which could be null, breaking the insert. **Fix:** Build `insertData` map, only include `id` if non-null.
7. **🔴 BUG-40-07 — Stale `activeConversationId`** — `copyWith` couldn't clear active conversation (null coalesce kept old value). **Fix:** Added `clearActiveConversation` flag.

**Phase 3 — Medium Severity (6 bugs):**
8. **🟡 BUG-40-08 — No `clearHourlyRate` in `WorkerProfile.copyWith`** — Added `clearHourlyRate` param.
9. **🟡 BUG-40-09 — `send-sms` undefined message** — `payload.message` could be undefined. **Fix:** Added fallback: `Your verification code is ${payload.otp}`.
10. **🟡 BUG-40-10 — Unencoded FCM token in URL** — `removeDeadToken` didn't URL-encode the token. **Fix:** Wrapped in `encodeURIComponent()`.
11. **🟡 BUG-40-11 — Missing `description` in application join** — `getMyApplications` didn't select `description`. **Fix:** Added to join query.
12. **🟡 BUG-40-12 — Budget parser picks non-budget numbers** — Numbers not near budget keywords (e.g., house numbers) could be parsed as budgets. **Fix:** Required `isNearKeyword` check on all branches.
13. **🟡 BUG-40-13 — Messages TO deleted user not cleaned** — `delete_user_data_rpc` only deleted messages BY the user. **Fix:** Added delete for messages on jobs the user applied to as a worker.

**Phase 4 — Low Severity (4 bugs):**
14. **🧹 BUG-40-14 — FCM token deletion not scoped** — `signOut()` deleted by token only, not user. **Fix:** Added `.eq('user_id', _currentUserId!)`.
15. **🧹 BUG-40-15 — OpenRouter retry only for `Exception`** — `Error` subtypes (e.g., `FormatException`) weren't retried. **Fix:** Removed `e is Exception` guard.
16. **🧹 BUG-40-16 — Missing 'Labor' category** — Post Job selector had gap at ID 21. **Fix:** Added `('Labor', 21)`.
17. **🧹 BUG-40-17 — Offline workers in smart matching** — Offline workers were scored/returned despite being unavailable. **Fix:** Added `AND wp.availability_status <> 'offline'` filter.

**Files Changed (14 + 1 new):**
| File | Phase |
|------|-------|
| `lib/features/chat/providers/chat_provider.dart` | 1.1, 2.3, 2.4 |
| `lib/features/auth/providers/auth_provider.dart` | 1.2 |
| `supabase/migrations/20260728000000_fix_nearby_workers_categories.sql` | 1.3, 2.1 |
| `lib/features/jobs/views/search_workers_view.dart` | 1.3 |
| `lib/core/services/supabase_repository.dart` | 2.2, 3.4 |
| `supabase/migrations/20260730000000_hire_worker_rpc.sql` (NEW) | 2.2 |
| `lib/features/worker/models/worker_profile_model.dart` | 3.1 |
| `supabase/functions/send-sms/index.ts` | 3.2 |
| `supabase/functions/send-push-notification/index.ts` | 3.3 |
| `supabase/functions/_shared/utils.ts` | 3.5 |
| `supabase/migrations/20260722000005_delete_user_data_rpc.sql` | 3.6 |
| `lib/core/services/notification_service.dart` | 4.1 |
| `lib/core/services/openrouter_service.dart` | 4.2 |
| `lib/features/jobs/views/post_job_view.dart` | 4.3 |
| `supabase/migrations/20260722000001_smart_matching_function.sql` | 4.4 |

**Code Review — 3 issues caught & fixed:**
- `conversation_id` removed from offline queue insert (column doesn't exist in schema)
- `conversations` table reference fixed → uses `applications.job_id` subquery
- `verifyOtp` network error message restored (was accidentally deleted)

**Code Health:**
- `flutter analyze`: **2 info-level issues** (pre-existing only) ✅
- `flutter test`: **140/140 pass** ✅

---

### Session 38: .env Asset Bundling Fix — Supabase Config Not Loading in Web Build

### Session 39: End-to-End Audit — 3 Critical Bugs Fixed

*Session 39 (comprehensive end-to-end codebase audit from console logs, found and fixed 3 bugs):*

**Console Errors Addressed:**
1. `Firebase init error: Null check operator used on a null value` — Web Firebase init crash
2. `POST https://.../rest/v1/applications 409 (Conflict)` — Duplicate application race condition
3. Unhandled `AuthException` during email sign-up

**🔴 Bugs Found & Fixed:**
1. **🔴 BUG-39-01 — Firebase.initializeApp() crashes on web with null check error** — `initializeFirebase()` called `Firebase.initializeApp()` without `FirebaseOptions`. On web, FlutterFire requires explicit options (no native config files). **Fix:** Added `kIsWeb` branch that reads FirebaseOptions from `--dart-define` env vars, gracefully skipping Firebase if web options aren't configured.

2. **🔴 BUG-39-02 — 409 Conflict on duplicate application insert** — `applyForJob()` in `SupabaseRepository` did a plain `.insert()` without handling unique constraint violations. If the user double-tapped "I'm Interested", the second insert hit the `(job_id, worker_id)` unique constraint and threw a 409. **Fix:** Added `PostgrestException` handler for code `'23505'` (unique_violation) that treats it as a no-op (application already exists).

3. **🔴 BUG-39-03 — signUpWithEmail() missing try-catch for AuthException** — Unlike `signInWithEmail()`, the `signUpWithEmail()` method had no error handling, so auth failures (e.g., email already registered) threw unhandled exceptions. **Fix:** Wrapped in try-catch with `AuthException` and `SocketException` handling, matching the existing pattern in `signInWithEmail()`.

**Changes Made:**
| File | Changes |
|------|---------|
| `lib/core/services/notification_service.dart` | `initializeFirebase()` now checks `kIsWeb` and passes `FirebaseOptions` from `--dart-define`; gracefully skips if web options are absent |
| `lib/core/services/supabase_repository.dart` | `applyForJob()` catches `PostgrestException` with code `'23505'` to prevent 409 crashes on duplicate application |
| `lib/features/auth/providers/auth_provider.dart` | `signUpWithEmail()` wrapped in try-catch with `AuthException` and `SocketException` handling |

**Code Health:**
- `flutter test`: **140/140 pass** ✅
- All existing tests continue to pass after fixes ✅

---

*Previous Session 38 (fixed `flutter_dotenv` `.env` file not being bundled in web builds, causing "Supabase not configured" and cascading 404 errors):*

**Problem:** The web app showed "Supabase is not configured" because `flutter_dotenv` loads `.env` from `assets/.env`, but:
- No `assets/` directory existed in the project
- No assets were declared in `pubspec.yaml` under `flutter > assets`
- `flutter build web` never bundled `.env` → `dotenv.load()` silently failed → `isSupabaseConfigured` returned `false`

🔴 **Bug Found & Fixed:**
1. **🔴 BUG-38-01 — `.env` not bundled in web builds** — Missing `assets/` directory and `pubspec.yaml` asset declaration caused `dotenv.load()` to fail, making `AppConstants.isSupabaseConfigured` return `false`. This prevented the entire Supabase-backed app from loading.

2. **🔴 BUG-38-02 — Flutter web service-worker cached old manifest without `.env`** — Even after bundling `.env`, the Flutter web service worker may serve the old `AssetManifest.bin.json` (from cache) which doesn't know about `.env`. The Flutter engine then fails to resolve `assets/.env` to the actual server path `assets/assets/.env`. **Fix:** Added `String.fromEnvironment()` fallback in `AppConstants._env()` so `--dart-define` values work even when dotenv asset loading fails.

**Changes Made:**
| File | Changes |
|------|---------|
| `lib/core/constants/app_constants.dart` | `_env()` now falls back to `String.fromEnvironment(key)` when `dotenv` isn't available |
| `pubspec.yaml` | Added `assets:` → `- assets/.env` under `flutter:` section |
| `.gitignore` | Added `assets/.env` (explicit, though redundant with existing `.env` pattern) |
| `assets/.env` | Created by copying root `.env` into new `assets/` directory |
| `scripts/build_web.sh` | New build script: reads `.env`, passes as `--dart-define`, copies `.env` to `build/web/assets/` post-build |

> ⚠️ **Flutter web hidden-file workaround:** `flutter build web` nests `assets/.env` under `build/web/assets/assets/.env` but the `AssetManifest.bin` maps it to `assets/.env` → `assets/.env` (wrong). The engine requests `/assets/.env` and gets 404. Two workarounds:
> 1. Post-build copy: `cp .env build/web/assets/.env` (automated by `scripts/build_web.sh`)
> 2. `--dart-define` fallback via `String.fromEnvironment()` (compiled into JS, always works)

**Code Health:**
- `flutter analyze`: **2 info-level issues** (pre-existing) ✅
- `flutter test`: **140/140 pass** ✅
- Web server running on **port 8080** (tmux session) ✅
- Web build includes `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` ✅
- `.env` bundled at `build/web/assets/assets/.env` and registered in `AssetManifest.bin.json` ✅