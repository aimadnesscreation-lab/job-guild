#!/usr/bin/env bash
# ─── pre-push.sh ───────────────────────────────────────────────────
# Run the same checks as CI before pushing.  Call manually or hook
# into .git/hooks/pre-push with:
#   cp scripts/pre-push.sh .git/hooks/pre-push && chmod +x .git/hooks/pre-push
set -euo pipefail

echo "━━━ 1/3  dart format (safe with standalone Dart) ━━━"
dart format --set-exit-if-changed .
echo "✅ Format OK"

echo "━━━ 2/3  flutter analyze ━━━"
flutter analyze --no-pub
echo "✅ Analyze OK"

echo "━━━ 3/3  flutter test ━━━"
flutter test --reporter expanded
echo "✅ Tests OK"

echo ""
echo "━━━ All checks passed — safe to push! ━━━"
