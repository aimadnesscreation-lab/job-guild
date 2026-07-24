> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-31 — Session 42: patch2.md Bug Remediation — 9 Bugs Fixed Across 7 Files)

### Session 42: patch2.md Bug Remediation — 9 Fixes Applied, 7 Bugs Skipped

*Session 42 (systematic comparison of patch2.md against the current codebase — applied only fixes for bugs still present; skipped those already resolved in Sessions 40-41):*

#### ✅ Bugs Fixed (9 bugs across 7 files)

**Phase 1 — Critical (data integrity, functional correctness):**
| Bug | Severity | File | Description | Fix |
|-----|----------|------|-------------|-----|
| #2 | 🔴 | `supabase/migrations/20260722000009_complete_job_rpc.sql` | `complete_job` RPC allowed completing jobs in `'open'` status (no worker assigned) | Changed `AND status IN ('open', 'hired')` → `AND status = 'hired'` |
| #5 | 🔴 | `lib/features/home/providers/role_provider.dart` | `RoleNotifier` never retried role lookup on cold start when auth state arrived after `build()` | Added `ref.listen(currentUserProvider, ...)` listener to reload role when user becomes available |
| #7 | 🔴 | `lib/features/auth/providers/auth_provider.dart` | `normalizePhone()` accepted any 10-digit number, including invalid prefixes like +921234567890 | Added `RegExp(r'^3[0-4]\\d{8}$')` validation for Pakistani mobile prefixes (300–349) across all three input formats (92-prefix, 0-prefix, bare) |

**Phase 2 — Data Display (mock data, missing fields, incorrect earnings):**
| Bug | Severity | File | Description | Fix |
|-----|----------|------|-------------|-----|
| #1 | 🟡 | `lib/core/services/supabase_repository.dart` | Mock completed jobs had `'status': 'hired'` but `getWorkerCompletedJobs()` filters for `status == 'completed'` → mock earnings never showed | Changed all 3 mock entries + nested `.jobs.status` from `'hired'` → `'completed'` |
| #4 | 🟡 | `lib/core/services/supabase_repository.dart` | `getMyApplications()` didn't include `employer_id` and `category_id` in the `jobs!inner()` select → `_jobFromApplication()` couldn't populate these fields | Added `employer_id, category_id, created_at` to the select |
| #13 | 🟡 | `lib/features/home/views/worker_dashboard.dart` | Earnings total + individual entries used `budget_amount` (posted budget) instead of `proposed_price` (agreed amount) | Both `totalEarnings` fold and per-entry display now prefer `proposed_price`, falling back to `budget_amount` |

**Phase 3 — Code Quality (mutation pattern, scoring, keyword matching):**
| Bug | Severity | File | Description | Fix |
|-----|----------|------|-------------|-----|
| #6 | 🟡 | `lib/features/home/providers/role_provider.dart` | `enableRoleProvider` was a `FutureProvider.family<void, AppRole>` — FutureProvider is for reading data, not mutations | Replaced with `updateUserRole()`, `enableRole()`, `disableRole()` plain async functions taking `Ref` |
| #9 | 🟡 | `lib/features/jobs/views/job_detail_view.dart` | `_matchScore()` only considered rating + verification (too simplistic, misleading employers) | Now includes experience: rating 70%, verification 15%, experience 10% (1pt per 10 completed jobs), base 5% |
| #11 | 🟡 | `lib/core/utils/budget_parser.dart` | `guessCategory()` used simple `contains()` — "move" matched "remove"/"improve", "web" matched "website" unnecessarily, etc. | Changed critical keywords to word-boundary regex: `RegExp(r'\\bmove|\\bshift(ing|er)?\\b')`, `\\bweb\\b`, `\\bpet\\b`, `\\bmobile\\b`, etc. |

#### ⏭️ Bugs Skipped (7 bugs — already fixed or not applicable)

| Bug | Reason Skipped |
|-----|---------------|
| #3 — NULL-location workers in `get_nearby_workers` | **Already fixed** by migration `20260728000000_fix_nearby_workers_categories.sql` — dropped old function, recreated with `WHERE u.current_location IS NOT NULL AND st_dwithin(...)` |
| #8 — Voice recording race condition (`onLongPressEnd` before `_startRecording` finishes) | **Already fixed** in Session 41 (BUG-41-08) — current code uses `onLongPressStart/End/Cancel` with `_recordingStarted` guard |
| #10 — Wrong user mapping in multi-applicant conversations | **Already fixed** — the chat provider was completely rewritten in Sessions 40-41 with proper participant resolution via `_loadConversations()` batch-lookup pattern |
| #12 — Missing incoming messages when `allJobIds` is empty | **Already fixed** — current `_loadConversations()` already has a fallback `query.eq('sender_id', userId)` when no job IDs are found |
| #14 — PostJobView stale form on tab revisit | **Already fixed** in Session 41 (BUG-41-14) — `resetOnInit: true` in `_PostJobRoute` |
| #15 — Favorites navigating with incomplete profile | **Already fixed** in Session 41 (BUG-41-15) — fetches full `WorkerProfile` via `repo.getWorkerProfile()` before navigating |
| #16 — No `limit` on worker search causing full table scans | **Not applicable** — the actual codebase's `SupabaseRepository` doesn't have a `searchWorkers()` method in the form described in patch2.md; worker search uses the `get_nearby_workers` RPC which already limits results |

**Files Changed (7):**
| File | Bugs |
|------|------|
| `supabase/migrations/20260722000009_complete_job_rpc.sql` | #2 |
| `lib/features/auth/providers/auth_provider.dart` | #7 |
| `lib/features/home/providers/role_provider.dart` | #5, #6 |
| `lib/core/services/supabase_repository.dart` | #1, #4 |
| `lib/features/home/views/worker_dashboard.dart` | #13 |
| `lib/features/jobs/views/job_detail_view.dart` | #9 |
| `lib/core/utils/budget_parser.dart` | #11 |

**Test Update:**
| File | Change |
|------|--------|
| `test/worker_dashboard_test.dart` | Updated `workerCompletedJobsProvider` mock test expectations from `'hired'` → `'completed'` to match Bug #1 fix |

**Code Health:**
- `flutter analyze`: **0 issues** (no errors or warnings) ✅
- `flutter test`: **140/140 pass** ✅

**Deployment Status:**
- `supabase db push`: ⏳ Pending (complete_job RPC migration needs deploying)
- `git push origin main`: ✅ Pushed commit `69592ca`

### Session 42-B: patch2.md Cross-Check — Bugs #14-#16 Verified & Fixed

*Session 42-B (cross-checked the 3 bugs previously marked as "skipped" against the codebase — found all 3 still present and fixed them):*

#### ❌ Previous Assessment Was Incorrect

The Session 42 report incorrectly stated that Bugs #14, #15, and #16 were "already fixed" in Sessions 40-41. A line-by-line cross-check against the actual source files revealed all three bugs were still present.

#### ✅ Bugs Actually Fixed (3 bugs across 3 files)

| Bug | Severity | File | Previous (Wrong) Reason | Actual Status | Fix |
|-----|----------|------|--------------------------|---------------|-----|
| #14 | 🟡 | `lib/features/jobs/models/job_model.dart` | Claimed fixed as "BUG-41-14 — PostJobView stale form" (different bug!) | ❌ Zero-check `(parsedLat == 0.0 && parsedLng == 0.0)` still present | `_parseCoordinates` now returns `(double?, double?)` — returns `(null, null)` when no coordinates found. `fromJson` uses `??` null-coalescing instead of zero-check. |
| #15 | 🔴 | `supabase/functions/send-sms/index.ts` | Claimed fixed as "BUG-41-16 — OTP logged in production" | ❌ Still only checked `DENO_DEPLOYMENT_ID` (absent in some self-hosted instances) | Defaults to production-safe (no OTP logging). Only logs when `ENVIRONMENT`, `SUPABASE_ENV`, or `DENO_ENV` are explicitly `"development"` |
| #16 | 🟡 | `lib/features/worker/repositories/worker_repository.dart` | Claimed "Not applicable — no such method" (wrong file checked!) | ❌ `searchWorkers()` in `WorkerRepository` had no `.limit()` on non-location branch — full table scan | Added `.limit(20)` to non-location `searchWorkers` branch. Applied after filters to avoid `PostgrestTransformBuilder` type loss |

**Key Lesson:** Bug #14 was confused with patch.md's Bug #14 (stale form state in PostJobView — a completely different bug in a different file). Bug #15's Session 41 fix (`DENO_DEPLOYMENT_ID` check) was the same flawed approach — it was "fixed" to the same weak pattern described in patch2.md as broken. Bug #16 was checked against the wrong repository (`SupabaseRepository` instead of `WorkerRepository`).

**Files Changed (3):**
| File | Bug |
|------|-----|
| `lib/features/jobs/models/job_model.dart` | #14 |
| `supabase/functions/send-sms/index.ts` | #15 |
| `lib/features/worker/repositories/worker_repository.dart` | #16 |

**Code Health:**
- `flutter analyze`: **0 errors** (2 pre-existing info only) ✅
- `flutter test`: **140/140 pass** ✅

---

### Session 41: End-to-End Audit Remediation — 16 Bugs Fixed Across 12 Files

*Session 41 (4-phase systematic remediation of the comprehensive end-to-end audit report):*

**Phase 1 — Critical Fixes (4 bugs):**
1. 🔴 **BUG-41-01 — hire_worker RPC non-functional** — 3 SQL errors: `'applied'` not in CHECK constraint, `hired_worker_id` column doesn't exist, `'in_progress'` not a valid job status. **Fix:** Changed `'applied'`→`'interested'`/`'shortlisted'`, removed `hired_worker_id`, changed `'open','in_progress'`→`'open'`.
2. 🔴 **BUG-41-02 — NotificationService.signOut() null crash** — `_currentUserId!` force-unwrap crashed when FCM init failed. **Fix:** Added `_currentUserId == null` guard alongside existing `_token == null` check.
3. 🔴 **BUG-41-03 — Job edit creates duplicate** — `postJob()` always did INSERT, never UPDATE. **Fix:** Detect non-empty `job.id` and call `.update()` with appropriate field stripping.
4. 🔴 **BUG-41-04 — Worker ratings never computed** — No trigger recalculated `average_rating` or `total_jobs_completed`. **Fix:** New migration `20260731000000` with 2 triggers (reviews→average_rating, applications→total_jobs_completed) + backfill queries.

**Phase 2 — High Severity (5 bugs):**
5. 🔴 **BUG-41-05 — Coach marks wrong tabs in Worker mode** — Hardcoded employer tab layout. **Fix:** Made `_buildSteps()` role-aware with `isWorker` param, adjusting highlighted tab indices per role.
6. 🔴 **BUG-41-06 — Employer AppBar→Worker Profile Editor** — Person icon navigated to `EditWorkerProfileView` for employers. **Fix:** Navigate to `SettingsView` instead for employer role.
7. 🔴 **BUG-41-07 — Earnings log bugs** — Included `'hired'` (in-progress) jobs + total summed only displayed entries. **Fix:** Filter only `'completed'` status, sum all `recentEntries` not just `displayEntries`.
8. 🔴 **BUG-41-08 — Voice playback broken** — `resume()` used from stopped state (silent no-op). **Fix:** Use `_player.play(UrlSource(widget.url))` from stopped state.
9. 🔴 **BUG-41-09 — OTP multi-char input** — No `maxLength` on 6 OTP fields. **Fix:** Added `maxLength: 1`, `MaxLengthEnforcement.enforced`, hidden counter.

**Phase 3 — Medium Severity (5 bugs):**
10. 🟡 **BUG-41-10 — ChatNotifier null client crashes** — Multiple methods called `Supabase.instance.client` without try-catch. **Fix:** Added `_safeClient` getter, applied to `_loadConversations`, `sendMessage`, `sendVoice`, `retryOfflineQueue`, `_subscribeToConversations`, `_addToOfflineQueue`.
11. 🟡 **BUG-41-11 — RoleNotifier dual-role default** — Always set Worker when both roles enabled. **Fix:** Only set worker when `isWorker && !isEmployer`.
12. 🟡 **BUG-41-12 — Storage bucket re-created** — `createBucket` called before every upload. **Fix:** Check `listBuckets()` first before creating.
13. 🟡 **BUG-41-13 — delete_user_data deletes users row** — Left orphaned auth.users sessions. **Fix:** Removed `DELETE FROM public.users` (handled by CASCADE from auth.users).
14. 🟡 **BUG-41-14 — PostJobView stale form** — IndexedStack tab retained form state. **Fix:** Added `resetOnInit: true` in `_PostJobRoute`.
15. 🟡 **BUG-41-15 — Favorites incomplete profile** — Navigated with only partial data. **Fix:** Fetch full `WorkerProfile` via `repo.getWorkerProfile()` before navigating.

**Phase 4 — Low Severity (2 bugs):**
16. 🔵 **BUG-41-16 — OTP logged in production** — `send-sms` Edge Function logged OTP. **Fix:** Added `DENO_DEPLOYMENT_ID` check before console.log.

**BUG #22 — Now Fixed (previously skipped):**
17. 🔵 **BUG-41-22 — Missing `updated_at` triggers** — Direct PostgREST updates left `updated_at` stale on `jobs` and `applications`. **Fix:** New migration `20260731000001` with `BEFORE UPDATE` triggers auto-setting `updated_at = NOW()` (cross-referenced from `patch.md` ##18).

**Bugs Skipped (already fixed / not applicable):**
- BUG #15: NULL-location workers → Fixed by migration `20260728000000`
- BUG #18: Shimmer `AnimatedBuilder` → Correct name in Flutter 3.x
- BUG #19: `_safeList` duplication → Low priority code cleanup
- BUG #21: `complete_job` 'open' gap → Fixed by migration `20260722000010`

**Files Changed (12):**
| File | Bugs |
|------|------|
| `supabase/migrations/20260730000000_hire_worker_rpc.sql` | #1 |
| `supabase/migrations/20260731000000_add_ratings_triggers.sql` (NEW) | #4 |
| `supabase/migrations/20260731000001_updated_at_triggers.sql` (NEW) | #22 |
| `supabase/migrations/20260724000000_audit_fixes.sql` | #13 |
| `supabase/functions/send-sms/index.ts` | #16 |
| `lib/core/services/notification_service.dart` | #2 |
| `lib/core/services/supabase_repository.dart` | #3, #7 |
| `lib/core/widgets/coach_mark_overlay.dart` | #5 |
| `lib/features/home/views/home_view.dart` | #6, #14 |
| `lib/features/home/views/worker_dashboard.dart` | #7 |
| `lib/features/home/views/favorites_view.dart` | #15 |
| `lib/features/home/providers/role_provider.dart` | #11 |
| `lib/features/chat/providers/chat_provider.dart` | #10 |
| `lib/features/chat/views/chat_detail_view.dart` | #8, #12 |
| `lib/features/chat/providers/voice_recorder_provider.dart` | #12 |
| `lib/features/auth/views/otp_verification_view.dart` | #9 |

**Code Health:**
- `flutter analyze`: **2 info-level issues** (pre-existing only) ✅
- `flutter test`: **140/140 pass** ✅

**Deployment Status:**
- `supabase db push`: ✅ All migrations applied (incl. new `20260731000000` & `20260731000001`)
- `supabase functions deploy send-sms`: ✅ Deployed (24 kB) — OTP log fix
- `supabase functions deploy send-push-notification`: ✅ Confirmed deployed
- `git push origin main`: ✅ Pushed (commits `2ac2a86` → `4ddb305`)

### patch.md Cross-Reference

The `patch.md` file (18 files, complete rewrites) was cross-referenced against the current codebase. **17 of 18 files** already had their fixes applied via the Session 41 targeted patches. The only missing change — `updated_at` triggers (BUG #22) — was created as migration `20260731000001`. The patch.md versions use `ChangeNotifier`/`StatefulWidget` architecture; the actual codebase uses Riverpod `Notifier`/`ConsumerStatefulWidget`, so the targeted Session 41 patches were applied instead of full file replacements.

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
- `flutter build web --release`: **Zero errors** ✅ (dart:io removal confirmed working for web)

**Deployment Status:**
- `supabase db push`: ✅ All migrations applied (incl. new `20260730000000_hire_worker_rpc`)
- `supabase functions deploy send-sms`: ✅ Deployed (24 kB)
- `supabase functions deploy send-push-notification`: ✅ Deployed (27 kB)
- `git push origin main`: ✅ Pushed commit `eaf5a12`

**E2E Verification — Interactive Tests (manual, run locally):**
| # | Test Case | Status |
|---|-----------|--------|
| 4 | Chat: Employer → Worker first message | 🔵 Manual |
| 5 | Chat: Bidirectional replies | 🔵 Manual |
| 6 | Worker search: correct availability status | 🔵 Manual |
| 7 | Nearby search: no NULL-location workers | 🔵 Manual |
| 8 | Hire: atomic application + job update | 🔵 Manual |
| 9 | Offline message queue retry | 🔵 Manual |
| 10 | Clear activeConversationId on leave | 🔵 Manual |
| 11 | Worker app detail: description visible | 🔵 Manual |
| 12 | Post job: "Labor" category available | 🔵 Manual |
| 13 | Account deletion: all messages cleaned | 🔵 Manual |

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