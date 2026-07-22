# AI Builder Prompt: Local Services Marketplace App

Copy everything below this line into your AI builder tool (Bolt, Lovable, Cursor, v0, Claude, etc.).

---

## 1. Project Overview

Build a two-sided mobile marketplace app connecting **employers** (people who need small, one-off, or short-term local jobs done) with **workers** (skilled and unskilled local labor: electricians, plumbers, cleaners, drivers, tutors, laborers, technicians, etc.).

This is **not** a full-time job board like LinkedIn/Indeed, and **not** a remote freelance platform like Upwork. It is a hyperlocal, fast-turnaround marketplace modeled conceptually on "Uber + Facebook Marketplace + WhatsApp": post a need, get matched with nearby verified people, chat, agree terms, get it done, rate each other.

The primary launch market is **Pakistan** (starting with a single city, e.g. Lahore), so the app must support **Urdu and English**, work well on **low-end Android devices** and **inconsistent mobile data**, and default currency to **PKR**.

The core differentiator is **trust** (verification, ratings, reviews, portfolios) and **speed** (instant job posting, instant matching, real-time chat) — not just listings.

---

## 2. Tech Stack (use exactly this unless a substitution is explicitly justified)

- **Mobile app:** Flutter (Dart), targeting Android first, iOS second.
- **Backend:** Supabase — Postgres database, Supabase Auth, Supabase Realtime (for chat and live job feeds), Supabase Storage (for photos/videos/portfolios/ID documents).
- **Push notifications:** Firebase Cloud Messaging (FCM), triggered via Supabase Edge Functions on relevant DB events.
- **AI:** OpenRouter (free tier) with Google Gemma 4 26B as the primary model for both job parsing (JSON extraction) and profile/bio generation. Falls back to the `openrouter/free` auto-router if the primary is rate-limited, and finally to keyword-based mock parsing/bio generation as a last resort so the app never breaks.
  - **Job parsing:** Free model (structured JSON extraction) — low temperature (0.1), strict JSON schema output.
  - **Profile generation:** Free model (text generation) — moderate temperature (0.5), 2-3 sentence bio + category suggestions.
  - **Cost control:** 3-tier fallback (Edge Function → client-side direct API → keyword mock). Results cached until user edits input. Never call AI on keystrokes — only on explicit button press.
- **Maps/Location:** OpenStreetMap via `flutter_map` package (completely free, no API key needed). Falls back to GPS for current location.
- **Localization:** Custom `AppStrings` class with full Urdu + English support, RTL-aware layout for Urdu text via `Directionality` widget.
- **State management:** Riverpod (preferred) or Bloc — pick one and use it consistently throughout.

Do not introduce additional backend services (no separate Node/Express API layer) unless a specific feature genuinely cannot be done via Supabase Edge Functions.

---

## 3. User Roles

Every account can toggle between **Employer mode** and **Worker mode** from the same profile (most users will eventually do both — e.g., a plumber might also need a tutor for his kid). Store role-specific data separately but keep a single unified `users` table as the identity anchor.

---

## 4. Data Model (Postgres via Supabase)

Implement these tables with appropriate foreign keys, indexes on location/category/status columns, and Row-Level Security policies so:
- Workers can only see jobs within their configured radius and matching category preferences.
- Users can only read/write their own messages, applications, and profile data.
- Reviews can only be written by a user who was party to a completed job.

**`users`**
id, phone_number (unique, verified), email (optional), full_name, profile_photo_url, city, current_lat, current_lng, preferred_language (ur/en), created_at, is_verified, id_verification_status (none/pending/verified), account_status (active/suspended).

**`worker_profiles`**
id, user_id (FK), headline, bio, categories (array/join table), years_experience, hourly_rate_or_fixed_note, availability_status (today/tomorrow/weekdays/weekends/morning/evening/busy/offline), service_radius_km, average_rating, total_jobs_completed, response_time_avg_minutes, portfolio_media (array of URLs), is_featured (bool, for monetization later).

**`categories`** (seeded, hierarchical: parent_category, subcategory)
Home (Plumbing, Electrical, Painting, Carpentry, Masonry), Vehicles (Mechanic, Bike Repair, Car Wash), Construction (Labor, Welding, Steel Fixing), Education (Tutor, Language Teacher), Technology (Laptop Repair, Mobile Repair, Web Developer), Events (Photographer, DJ, Cook), Delivery, Cleaning, Moving, Healthcare, Beauty, Pet Care, General Labor.

**`jobs`**
id, employer_id (FK), category_id (FK), title, description (raw text as entered), ai_extracted_summary (jsonb: category, urgency, suggested_budget, estimated_duration, required_skills), budget_amount, budget_type (fixed/hourly/negotiable), location_lat, location_lng, location_text, status (open/hired/completed/cancelled/expired), urgency (instant/today/scheduled), scheduled_for (nullable timestamp), created_at.

**`applications`**
id, job_id (FK), worker_id (FK), status (interested/shortlisted/hired/rejected), applied_at, message (optional initial note).

**`messages`**
id, conversation_id (job_id + employer_id + worker_id composite or separate `conversations` table), sender_id, content_type (text/image/voice/location/file), content, sent_at, read_at.

**`reviews`**
id, job_id (FK), reviewer_id, reviewee_id, rating (1-5), comment, created_at. Enforce one review per role per job.

**`favorites`**
user_id, favorited_user_id, created_at (for both "saved workers" and "favorite employers").

**`reports`**
id, reporter_id, reported_user_id, job_id (nullable), reason, details, status (open/reviewed/actioned), created_at.

**`notifications`**
id, user_id, type, payload (jsonb), is_read, created_at.

---

## 5. Screens (Phase 1 MVP — build all of these)

1. **Onboarding / Auth** — phone number entry, OTP verification, language selection (Urdu/English), role selection prompt (can skip and choose later).
2. **Home Feed (Worker mode)** — list/map toggle of nearby open jobs, filterable by category, budget, distance, urgency. Instant/emergency jobs visually highlighted (badge + sort priority).
3. **Home Feed (Employer mode)** — "Post a Job" prominent CTA, plus browsing/searching workers by category, location, rating, availability.
4. **Post a Job screen** — freeform text box ("what do you need?") that is sent to the AI parsing pipeline (see Section 6) to auto-fill category, urgency, suggested budget, and estimated duration, all of which the employer can review/edit before posting. Also manual fields: location (map picker, defaults to current GPS), budget, scheduling (now/today/specific time).
5. **Job Detail screen (Employer view)** — shows list of interested workers sorted by AI match score, each with rating, distance, response time, verified badge; tap to open chat; "Hire" and "Mark Complete" actions.
6. **Job Detail screen (Worker view)** — job info, "I'm Interested" button, employer's rating, distance, chat access once interested.
7. **Worker Profile (own, editable)** — photo, headline, bio (with "generate from description" AI helper), categories, experience, availability toggle, service radius, portfolio upload (photos/videos), verification status/CTA.
8. **Worker Profile (public view, as seen by employer)** — same info read-only, plus reviews list, "Hire" and "Message" and "Save" actions.
9. **Chat screen** — WhatsApp-style: text, images, voice notes, location sharing, typing indicator, read receipts. Scoped per job/application.
10. **Search/Browse Workers screen** — filters: category, distance, price range, rating, availability, verified-only, language spoken.
11. **Ratings & Review screen** — triggered after a job is marked complete by either party; star rating + free-text comment.
12. **Notifications screen** — new job matches, new messages, application updates, job status changes.
13. **Employer Dashboard** — active jobs, applicants per job, completed job history, saved workers.
14. **Worker Dashboard** — nearby jobs count, applied jobs, messages, ratings summary, profile views, earnings log (manual/optional entries, no real payment processing yet).
15. **Settings** — language, notification preferences, service radius, account, verification, logout, report/block management, delete account.

---

## 6. AI Integration Details (be specific — implement exactly this behavior)

### 6.1 Job parsing (on "Post a Job")
When the employer finishes typing a freeform description, call the AI model via the `bright-api` Supabase Edge Function with a system prompt instructing it to return **only** a JSON object (no prose, no markdown fences) with these fields:
```json
{
  "category": string (must match one of the seeded category names),
  "urgency": "instant" | "today" | "scheduled",
  "suggested_budget_pkr": number,
  "estimated_duration_hours": number,
  "required_skills": string[]
}
```
Show these as editable pre-filled fields in the Post a Job form — never auto-submit without employer confirmation.

**Fallback chain:**
1. Edge Function `bright-api` → OpenRouter `google/gemma-4-26b-a4b-it:free` → `openrouter/free` auto-router
2. Client-side `OpenRouterService` (Flutter) → same models via `.env` key
3. Keyword-based mock parsing in Dart (always works, no API needed)

### 6.2 Worker profile generation
On the worker profile screen, offer a "Let AI write my profile" option: worker types a rough freeform description of their experience (e.g., "I worked in construction for 8 years"), and the `rapid-worker` Edge Function returns a polished 2-3 sentence professional bio plus a suggested list of relevant categories/skills. Worker can edit before saving.

**Fallback chain:**
1. Edge Function `rapid-worker` → OpenRouter `google/gemma-4-26b-a4b-it:free` → `openrouter/free` auto-router
2. Keyword-based fallback in TypeScript

### 6.3 Smart matching
When a job is posted, run a scoring pass (a plain Postgres weighted-scoring function — `match_workers_for_job`) that ranks nearby eligible workers by: distance (40pts), rating (25pts), past completed jobs in that category (15pts), availability status match (10pts), and historical response speed (10pts). Surface the top matches to the employer and push-notify those workers.

### 6.4 Cost control
Cache/reuse AI parsing results where possible (via `PostJobState.parsedResult`), use free models by default, never call the AI on every keystroke — only on explicit user action (e.g., "Parse with AI" button, "Generate Bio" button).

---

## 7. Core Feature Behavior Details

- **Verification:** Phone verification is mandatory for all accounts (Phase 1). ID/selfie verification is optional but earns a "Verified" badge that boosts search ranking and match score. Do not gate basic app usage behind ID verification — many workers in this market won't have easy access to that flow initially.
- **Job lifecycle:** open → (employer receives interested workers) → hired (one worker selected, job disappears from other workers' feeds) → completed (either party can mark; triggers mutual review prompt) → cancelled (employer or worker, with reason).
- **Instant/Emergency jobs:** Jobs marked "instant" get a highlighted badge, appear at the top of the worker feed, and trigger immediate push notifications to eligible nearby workers (not a digest).
- **Availability status:** Workers must actively set this (today/tomorrow/weekdays/weekends/morning/evening/busy/offline); workers marked "offline" or "busy" should not receive instant-job push notifications.
- **Ratings:** Mandatory two-way rating after job completion (both employer and worker rate each other); average rating and total-completed-jobs count are shown prominently everywhere a worker profile appears.
- **Reporting/blocking:** Available from any chat or profile screen; reported users get flagged for manual review, not auto-suspended.
- **No in-app payments in Phase 1.** Employer and worker agree on payment method (cash, bank transfer, etc.) outside the app. Design the data model so an `escrow`/`transactions` table can be added later without breaking existing schema (Phase 3, likely via JazzCash/Easypaisa APIs).

---

## 8. Design & UX Guidelines

- Design for **one-handed use on mid/low-end Android phones** — large tap targets, minimal text entry, heavy use of icons and photos over dense text.
- **Urdu support** is not optional — every user-facing string must be localized, and Urdu text should render correctly with appropriate RTL text direction and a warm community-marketplace visual language.
- Visual language should feel like a **local community marketplace**, not a corporate B2B tool — warm, approachable, photo-forward (worker portfolio photos, profile photos), not sterile enterprise UI.
- Use **skeleton loaders** and **optimistic UI updates** for chat and job posting, since users will often be on 3G/patchy connections.
- Keep the "Post a Job" flow to **under 30 seconds** for a returning user — this is the single most important conversion flow in the app.

---

## 9. Non-Functional Requirements

- App must remain usable with intermittent connectivity: queue outgoing messages/job posts locally and sync when back online.
- Push notifications must work reliably even when the app is backgrounded or killed (test FCM background delivery specifically).
- All location queries must be efficient at scale — use PostGIS (available in Supabase) for radius-based job/worker queries rather than naive lat/lng math.
- Structure the codebase so payments, video calling, and dispute resolution (Phase 3 features) can be added without major refactors.

---

## 10. Explicit Out-of-Scope for This Build (do not implement yet)

- In-app payments or escrow.
- Video/voice calling (chat only for now).
- AI fraud detection beyond the basic report/block flow.
- Business/enterprise accounts and analytics dashboards.
- Recurring/scheduled service subscriptions.

---

## 11. Deliverable Expectations

Produce a working Flutter app connected to a real Supabase project (schema + RLS policies included), with the screens above implemented and navigable, seeded category data, working phone-OTP auth, a functioning job-post-to-chat-to-review flow end-to-end, and the AI job-parsing and profile-generation features working against the OpenRouter API. Provide clear setup instructions for Supabase project creation, environment variables (Supabase URL/key, OpenRouter API key, FCM config), and how to run the app locally.
