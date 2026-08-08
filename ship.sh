#!/usr/bin/env bash
# ship.sh — end-of-session routine for the funnel site.
#
#   1. Snapshots index.html into prev-version/ with a timestamp
#   2. Deploys the folder to Vercel
#
# Run it from anywhere:
#     bash "ushamiami/Lead Generation/funnel-site/ship.sh"           # preview URL
#     bash "ushamiami/Lead Generation/funnel-site/ship.sh" --prod    # production
#
# Preview is the default on purpose. A preview gives you a real URL to click
# without putting anything in front of the public, which matters while the
# legal pages are still unreviewed and the 5test shortcut is still in the file.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

PROD=0
[ "${1:-}" = "--prod" ] && PROD=1

# ---------------------------------------------------------------- 1. backup
mkdir -p prev-version
STAMP="$(date +%Y-%m-%d-%H%M)"
SNAP="prev-version/index-$STAMP.html"

if [ ! -f index.html ]; then
  echo "ERROR: no index.html in $HERE — nothing to ship." >&2
  exit 1
fi

# Don't write a duplicate if nothing changed since the last snapshot.
LATEST="$(ls -1 prev-version/index-*.html 2>/dev/null | tail -1 || true)"
if [ -n "$LATEST" ] && cmp -s index.html "$LATEST"; then
  echo "[backup] unchanged since $(basename "$LATEST") — no new snapshot"
  SNAP="$LATEST"
else
  cp index.html "$SNAP"
  echo "[backup] saved $SNAP ($(wc -c < "$SNAP") bytes)"
fi

echo "[backup] prev-version now holds $(ls -1 prev-version/index-*.html 2>/dev/null | wc -l) version(s)"

# ------------------------------------------------------------- 2. pre-flight
# Loud warnings, not blockers. Shipping is your call; being surprised isn't.
WARN=0
if grep -q "DEV_SHORTCUT" index.html; then
  echo "[warn] the 5test dev shortcut is still in this file"
  WARN=1
fi
if grep -qE '(url|anonKey): *""' index.html; then
  echo "[warn] CONFIG.supabase is missing a url or anonKey — leads would save only in the"
  echo "       visitor's own browser and never reach you"
  WARN=1
fi
if [ "$PROD" = "1" ] && [ "$WARN" = "1" ]; then
  echo
  read -r -p "Deploy to PRODUCTION anyway? [y/N] " ok
  case "$ok" in y|Y|yes|YES) ;; *) echo "Stopped. Nothing deployed."; exit 0 ;; esac
fi

# ---------------------------------------------------------------- 3. deploy
# prev-version/ is history, not part of the site — never publish it.
cat > .vercelignore <<'EOF'
prev-version/
.gstack/
ship.sh
README.md
EOF

echo "[deploy] starting…"
if [ "$PROD" = "1" ]; then
  npx --yes vercel@latest deploy --prod --yes
else
  npx --yes vercel@latest deploy --yes
fi
