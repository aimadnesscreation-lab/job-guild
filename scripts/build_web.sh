#!/usr/bin/env bash
# ─── Build Flutter web with env vars compiled in ──────────────────────
# This script reads the .env file, passes values as --dart-define (so they
# work even if the asset bundle fails), then copies .env to build/web/assets/
# so the Flutter engine can fetch it at the expected path.
#
# Usage:  ./scripts/build_web.sh
# After:   tmux kill-session -t web-server
#          cd build/web && tmux new-session -d -s web-server 'python3 -m http.server 8080'

set -euo pipefail

cd "$(dirname "$0")/.."

# Read .env, skip comments and blanks
source_env() {
  local key="$1"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2- | tr -d '\r' || echo ""
}

SUPABASE_URL="$(source_env SUPABASE_URL)"
SUPABASE_ANON_KEY="$(source_env SUPABASE_ANON_KEY)"
OPENROUTER_API_KEY="$(source_env OPENROUTER_API_KEY)"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env"
  exit 1
fi

echo "Building with --dart-define..."
echo "  SUPABASE_URL = ${SUPABASE_URL}"
echo "  SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY:0:20}..."

flutter build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
  ${OPENROUTER_API_KEY:+--dart-define="OPENROUTER_API_KEY=${OPENROUTER_API_KEY}"}

# Post-build: copy .env so Flutter engine finds it at /assets/.env
cp .env build/web/assets/.env

echo ""
echo "✅ Build complete!"
echo "   main.dart.js  → build/web/main.dart.js"
echo "   .env copy     → build/web/assets/.env"
echo ""
echo "To start the server:"
echo "  tmux new-session -d -s web-server -c build/web 'python3 -m http.server 8080'"
