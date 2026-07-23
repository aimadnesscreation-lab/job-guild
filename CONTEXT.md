> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.

# Context File for AI-Assisted Development

## Project Overview

**Local Services Marketplace** — A two-sided mobile marketplace connecting employers (people who need local services) with workers (skilled and unskilled local labor) in Pakistan. Built with Flutter + Supabase.

**Target Market:** Pakistan (Lahore first), Urdu + English, PKR currency, low-end Android optimization.

## Current State (Updated 2026-07-30 — Session 38: .env Bundling Fix + Web Server)

### Session 38: .env Asset Bundling Fix — Supabase Config Not Loading in Web Build

*Session 38 (fixed `flutter_dotenv` `.env` file not being bundled in web builds, causing "Supabase not configured" and cascading 404 errors):*

**Problem:** The web app showed "Supabase is not configured" because `flutter_dotenv` loads `.env` from `assets/.env`, but:
- No `assets/` directory existed in the project
- No assets were declared in `pubspec.yaml` under `flutter > assets`
- `flutter build web` never bundled `.env` → `dotenv.load()` silently failed → `isSupabaseConfigured` returned `false`

🔴 **Bug Found & Fixed:**
1. **🔴 BUG-38-01 — `.env` not bundled in web builds** — Missing `assets/` directory and `pubspec.yaml` asset declaration caused `dotenv.load()` to fail, making `AppConstants.isSupabaseConfigured` return `false`. This prevented the entire Supabase-backed app from loading.

**Changes Made:**
| File | Changes |
|------|---------|
| `pubspec.yaml` | Added `assets:` → `- assets/.env` under `flutter:` section |
| `.gitignore` | Added `assets/.env` (explicit, though redundant with existing `.env` pattern) |
| `assets/.env` | Created by copying root `.env` into new `assets/` directory |

**Code Health:**
- `flutter analyze`: **2 info-level issues** (pre-existing) ✅
- `flutter test`: **140/140 pass** ✅
- Web server running on **port 8080** (tmux session) ✅
- `.env` bundled at `build/web/assets/assets/.env` and registered in `AssetManifest.bin.json` ✅