# Job Guild — Local Services Marketplace

A **two-sided mobile marketplace** connecting **employers** (people who need local services) with **workers** (skilled and unskilled local labor) in Pakistan. Think "Uber + Facebook Marketplace + WhatsApp" for local services — instant job posting, real-time matching, and in-app chat.

> **Primary Market:** Lahore, Pakistan  
> **Currency:** PKR  
> **Languages:** English + Urdu (full RTL support)  
> **Target Devices:** Low-end Android phones, inconsistent mobile data

---

## 📖 Table of Contents

- [Screenshots](#-screenshots)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Screens (15 Total)](#-screens-15-total)
- [Database Schema](#-database-schema)
- [AI Integration](#-ai-integration)
- [Getting Started](#-getting-started)
- [Configuration](#-configuration)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [Project Structure](#-project-structure)
- [Roadmap](#-roadmap)

---

## ✨ Features

### For Employers
- **Post a Job in 30 seconds** — Type "Need a plumber for leaking faucet, budget 2000, urgent" → AI auto-fills category, urgency, budget, and duration
- **Live Worker Feed** — Browse nearby workers with ratings, distance, and availability
- **Smart Matching** — Workers are ranked by distance, rating, past job completion, and response speed
- **Real-time Chat** — WhatsApp-style messaging per job with text, images, and location sharing
- **Hire & Review** — One-tap hiring, mutual two-way ratings after job completion

### For Workers
- **Live Job Feed** — See nearby open jobs in real-time via Supabase Realtime subscriptions
- **Instant Job Alerts** — Emergency/urgent jobs highlighted with badges and priority placement
- **Profile Portfolio** — Upload photos/videos, set availability, AI-assisted bio generation
- **Availability Toggle** — Set status (Today/Tomorrow/Weekdays/Offline) to control notifications
- **Verified Badge** — Optional ID verification boosts search ranking

### Platform Features
- 📱 **Phone OTP Auth** — Mandatory phone verification (Pakistan numbers `+92`)
- 🌐 **Urdu + English** — Full bilingual support with RTL layout for Urdu
- ⚡ **Optimistic UI** — Messages post instantly, jobs appear immediately
- 🔄 **Realtime Everywhere** — Job feed, chat, and notifications update live via Supabase Realtime
- 🛡️ **RLS Security** — Row-Level Security on all tables, users only see their own data
- 📍 **PostGIS Location** — Efficient radius-based geo-queries for nearby jobs and workers
- 📵 **Offline Resilience** — Queues messages locally when offline, syncs when reconnected

---

## 🛠 Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Mobile** | Flutter 3.x (Dart) | Cross-platform UI (Android first) |
| **State** | Riverpod 3.x | Reactive state management |
| **Backend** | Supabase | Postgres DB, Auth, Realtime, Storage, Edge Functions |
| **Database** | PostgreSQL 17 + PostGIS | Relational data + location queries |
| **Auth** | Supabase Auth | Phone OTP, email/password, Row-Level Security |
| **Realtime** | Supabase Realtime | WebSocket subscriptions for job feed + chat |
| **AI** | OpenRouter (free models) | Job description parsing, profile generation |
| **Maps** | Google Maps Platform | Location picker, place autocomplete |
| **Push** | Firebase Cloud Messaging | Push notifications via Supabase Edge Functions |
| **Localization** | Flutter `intl` | Urdu + English with RTL support |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Auth UI  │  │ Home Tab │  │ Chat Detail  │   │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│       │              │               │           │
│  ┌────▼──────────────▼───────────────▼───────┐   │
│  │         Riverpod Providers                │   │
│  │  (Notifier, StreamProvider, Provider)     │   │
│  └────┬──────────────┬───────────────┬───────┘   │
│       │              │               │           │
│  ┌────▼────┐  ┌─────▼──────┐  ┌─────▼───────┐   │
│  │AuthRepo │  │ JobRepo    │  │ ChatRepo    │   │
│  └────┬────┘  └─────┬──────┘  └─────┬───────┘   │
└───────┼──────────────┼───────────────┼───────────┘
        │              │               │
        ▼              ▼               ▼
┌─────────────────────────────────────────────────┐
│               Supabase (Backend)                 │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Auth    │  │ Postgres │  │  Realtime    │   │
│  │ (OTP)    │  │ (+PostGIS)│  │ (WebSocket)  │   │
│  └──────────┘  └────┬─────┘  └──────────────┘   │
│                     │                            │
│              ┌──────▼──────┐                    │
│              │ Edge Functions│                    │
│              │ send-sms    │                    │
│              │ bright-api  │                    │
│              └──────┬──────┘                    │
└─────────────────────┼────────────────────────────┘
                      │
                      ▼
              ┌──────────────────┐
              │    OpenRouter    │
              │ (Free AI Models) │
              └──────────────────┘
```

### Key Architecture Decisions

**Riverpod v3 for State Management** — Notifier for mutable state (auth flow, chat, job posting form), StreamProvider for live data (job feed via Realtime), Provider for singletons (AI service, repositories).

**Realtime Data Flow** — Job feed uses `supabase.from('jobs').stream(primaryKey: ['id'])` which opens a WebSocket subscription. Any INSERT/UPDATE/DELETE on the `jobs` table immediately updates all connected clients. Chat messages use `onPostgresChanges` on the `messages` table for real-time message delivery.

**AI with Graceful Degradation** — Job parsing uses a 3-tier fallback:
1. **Edge Function** (`bright-api`) → server-side OpenRouter call (API key protected)
2. **Direct Flutter** → client-side OpenRouter call (if edge function unavailable)
3. **Keyword Mock** → pattern matching without any API call (always works)

**PostGIS Geography** — Location stored as `GEOGRAPHY(POINT, 4326)` for efficient radius queries. The `get_nearby_jobs` and `get_nearby_workers` RPC functions use `ST_DWithin` for spatial indexing.

---

## 📱 Screens (15 Total)

| # | Screen | File | Status |
|---|--------|------|--------|
| 1 | Onboarding / Auth | `language_selection_view.dart` + `otp_verification_view.dart` | ✅ Phone OTP flow complete |
| 2 | Home Feed (Worker) | `home_view.dart` (`_HomeFeedTab`) | ✅ Live Realtime jobs |
| 3 | Home Feed (Employer) | `home_view.dart` (welcome card) | ✅ Quick actions |
| 4 | Post a Job | `post_job_view.dart` | ✅ AI parsing with 3-tier fallback |
| 5 | Job Detail (Employer) | `job_detail_view.dart` | ✅ Placeholder |
| 6 | Job Detail (Worker) | `job_detail_worker_view.dart` | ✅ Placeholder |
| 7 | Worker Profile (edit) | `edit_worker_profile_view.dart` | ✅ AI bio generation button |
| 8 | Worker Profile (public) | `worker_public_profile_view.dart` | ✅ Read-only + reviews |
| 9 | Chat | `chat_detail_view.dart` / `chat_list_view.dart` | ✅ Realtime messaging |
| 10 | Search Workers | `search_workers_view.dart` | ✅ Filters |
| 11 | Ratings & Review | `review_view.dart` | ✅ Mutual reviews |
| 12 | Notifications | `notifications_view.dart` | ✅ View |
| 13 | Employer Dashboard | `employer_dashboard.dart` | ✅ Stats |
| 14 | Worker Dashboard | `worker_dashboard.dart` | ✅ Stats |
| 15 | Settings | `settings_view.dart` | ✅ Language, account, logout |

---

## 🗄 Database Schema

**11 tables** with Row-Level Security, foreign keys, and PostGIS geography:

| Table | Purpose | RLS |
|-------|---------|-----|
| `users` | User accounts (extends auth.users) | Public read, owner write |
| `categories` | 31 bilingual categories/subcategories | Public read |
| `worker_profiles` | Worker details, availability, portfolio | Public read, owner write |
| `worker_categories` | Worker → category mapping | Owner access |
| `jobs` | Job listings with PostGIS location | Public read, employer insert/update |
| `applications` | Worker → job applications | Participant access |
| `messages` | Chat messages per job | Participant access |
| `reviews` | Mutual job ratings | Public read, participant insert |
| `notifications` | User notifications | Owner only |
| `favorites` | Saved workers/employers | Owner only |
| `reports` | User reports (moderation) | Reporter only |

### PostGIS Functions

```sql
-- Find jobs within radius (km)
SELECT * FROM get_nearby_jobs(lat, lng, radius_km);

-- Find available workers within radius
SELECT * FROM get_nearby_workers(lat, lng, radius_km);
```

---

## 🤖 AI Integration

### Job Parsing (`bright-api` Edge Function)
When an employer types a freeform description:
1. Flutter sends description to `GET /functions/v1/bright-api`
2. Edge Function calls OpenRouter with `mistralai/mistral-7b-instruct:free`
3. Returns: `{ category, urgency, suggested_budget_pkr, estimated_duration_hours, required_skills }`
4. Fields pre-filled in the form — employer reviews/edits before posting

**Fallbacks:** If rate-limited (429), retries with `meta-llama/llama-3.1-8b-instruct:free`. If AI unavailable, uses keyword matching.

### Profile Generation (Planned)
Worker types rough experience → AI returns polished 2-3 sentence bio + relevant categories.

### Smart Matching (Planned)
When a job is posted, rank eligible workers by: distance, rating, completed jobs in category, availability, response speed.

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (^3.12.2) — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Supabase account** — [Free tier](https://supabase.com)
- **OpenRouter account** — [Free signup](https://openrouter.ai) (for AI features)
- **Google Maps API key** — [Get one](https://console.cloud.google.com) (optional for MVP)

### Step 1: Clone & Dependencies

```bash
git clone https://github.com/aimadnesscreation-lab/job-guild.git
cd job-guild
flutter pub get
```

### Step 2: Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Run the migrations in your Supabase SQL Editor:
   ```bash
   # Or use the Supabase CLI:
   supabase db push
   ```
3. Go to **Authentication → Settings** and enable **Phone** provider
4. Configure the **Send SMS Hook** to point to your Edge Function:
   - URL: `https://<project>.supabase.co/functions/v1/send-sms`
5. Set Edge Function secrets:
   ```bash
   supabase secrets set SMS_PROVIDER=log
   supabase secrets set OPENROUTER_API_KEY=<your-key>
   ```

### Step 3: Configure `app_constants.dart`

Open `lib/core/constants/app_constants.dart` and update:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
static const String openRouterApiKey = 'YOUR_OPENROUTER_KEY'; // Optional
```

### Step 4: Run

```bash
flutter run
```

For web (requires Chrome):
```bash
flutter run -d chrome
```

---

## ⚙️ Configuration Reference

### Feature Flags (`app_constants.dart`)

| Flag | Default | Description |
|------|---------|-------------|
| `enableAiJobParsing` | `true` | Enable AI parsing on Post Job screen |
| `enableAiProfileGeneration` | `true` | Enable AI bio generation |
| `useMockAi` | `false` | Skip all AI API calls, use keyword mock |

### Environment Variables (Supabase Secrets)

```bash
# Set via supabase CLI
supabase secrets set SMS_PROVIDER=log          # 'log' for dev, 'twilio'/'textlocal' for prod
supabase secrets set OPENROUTER_API_KEY=<key>  # Required for AI features
```

---

## 🧪 Testing

```bash
# Run all tests (36 total)
flutter test

# Run specific test suites
flutter test test/supabase_connection_test.dart    # 8 live Supabase tests
flutter test test/e2e_flow_test.dart               # 15 schema validation tests
flutter test test/widget_test.dart                 # 21 widget UI tests
```

### What's Tested

- **Widget tests (21):** All 15 screens render correctly with mock data
- **Supabase connection (8):** Live database connectivity, Realtime, PostGIS RPC, seed data
- **Schema validation (15):** All 11 tables, PostGIS functions, auth endpoint, Realtime channels

---

## 📁 Project Structure

```
local_services_marketplace/
├── lib/
│   ├── core/
│   │   ├── constants/        # App config, feature flags
│   │   ├── localization/     # Urdu/English strings, locale provider
│   │   ├── services/         # OpenRouter AI service, Supabase repository
│   │   └── theme/            # Material 3 theme definition
│   └── features/
│       ├── auth/             # Phone OTP flow
│       ├── home/             # Main tab screen + dashboards
│       ├── jobs/             # Job posting, feed, search, detail
│       ├── chat/             # Real-time messaging
│       ├── worker/           # Profile, public view
│       ├── notifications/    # Notifications view
│       └── settings/         # Settings, language, logout
├── supabase/
│   ├── functions/
│   │   ├── send-sms/         # SMS hook for phone OTP
│   │   └── bright-api/       # OpenRouter proxy for AI job parsing
│   └── migrations/           # Database schema migrations
├── test/                     # 36 tests across 3 files
└── pubspec.yaml              # Flutter dependencies
```

---

## 📋 Roadmap

### Phase 1 — MVP ✅ (Current)
- [x] 15 screens navigable with mock data
- [x] Supabase database with 11 tables + RLS
- [x] Phone OTP authentication (dev mode)
- [x] AI job parsing via OpenRouter Edge Function
- [x] Real-time job feed via Supabase Realtime
- [x] Real-time chat messaging
- [x] Urdu + English localization
- [x] 36 passing tests

### Phase 2 — Polish & Connect
- [ ] Google Maps integration for location picker
- [ ] Firebase Cloud Messaging push notifications
- [ ] AI worker profile generation Edge Function
- [ ] Smart worker-job matching algorithm
- [ ] Portfolio upload (Supabase Storage)
- [ ] ID verification flow

### Phase 3 — Production
- [ ] In-app payments via JazzCash/Easypaisa
- [ ] Video/voice calling
- [ ] Dispute resolution system
- [ ] Business/enterprise accounts
- [ ] Recurring service subscriptions

---

## 🤝 Contributing

This project is in active development. See `CONTEXT.md` for the technical context document used by AI coding assistants.

---

## 📄 License

MIT License — See LICENSE file for details.
