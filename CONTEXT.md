> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-30 — Session 37: End-to-End Audit Pass 6)

### Session 37: End-to-End Audit Pass 6 — 1 Bug Fixed + Comprehensive File-by-File Review

*Session 37 (thorough file-by-file audit of all 51 Dart source files, 9 test files, 26 SQL migrations, 10 TS files; found 1 new bug, fixed same; all tests pass):*

**Audit Summary:** Codebase in excellent health. After 5 prior audit sessions (31-36) fixing 49+ bugs, only 1 remaining bug was found — a UI alignment issue in the tutorial coach marks.

🔴 **Bug Found & Fixed (1):**
1. **🔴 BUG-37-01 — `CoachMarkOverlay` default `tabCount=5` misaligned tutorial highlights** (`coach_mark_overlay.dart`) — Both worker and employer bottom navigation bars have **4 tabs** (not 5), but `CoachMarkOverlay` defaulted to `tabCount: 5`. This caused the highlight circle positions to be calculated with `tabWidth = navWidth / 5` instead of `navWidth / 4`, misaligning the coach mark spotlight by ~20% per tab. **Fix:** Changed default from `5` to `4`.

**File-by-File Audit Coverage:**
| Area | Files Reviewed | Issues Found |
|------|:-------------:|:------------:|
| Core (services, utils, theme, constants, localization) | 12 | 0 |
| Auth (provider + 4 views) | 5 | 0 |
| Home (provider + 4 views) | 5 | 0 |
| Jobs (models, providers, 5 views) | 8 | 0 |
| Chat (models, providers, 2 views) | 5 | 0 |
| Worker (models, repository, providers, 3 views) | 6 | 0 |
| Ratings (2 views) | 2 | 0 |
| Notifications (1 view) | 1 | 0 |
| Settings (provider + 2 views) | 3 | 0 |
| Widgets (shimmer, coach_mark) | 2 | 1 (tabCount) |
| Providers (tutorial) | 1 | 0 |
| Edge Functions (4) | 4 | 0 |
| SQL Migrations (27) | 27 | 0 |
| Tests (9 files) | 9 | 0 |

**Changed Files:**
| File | Changes |
|------|---------|
| `lib/core/widgets/coach_mark_overlay.dart` | `tabCount` default: 5 → 4 |

**Code Health:**
- `dart analyze`: **2 info-level issues** (pre-existing, non-critical naming in test files) ✅
- `flutter test`: **140/140 pass** ✅
- Deno smoke test: **17/17 pass** ✅
- Edge Function tests: **15/15 pass** ✅
