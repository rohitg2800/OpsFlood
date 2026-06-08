#!/usr/bin/env bash
# =============================================================================
# scripts/download_fonts.sh
# Downloads JetBrains Mono TTF files into assets/fonts/
# Run once from the project root:  bash scripts/download_fonts.sh
# Retries up to 3 times; falls back to jsDelivr CDN mirror on failure.
# =============================================================================
set -euo pipefail

FONT_DIR="assets/fonts"
mkdir -p "$FONT_DIR"

# Primary: GitHub raw  |  Fallback: jsDelivr CDN (global CDN, no rate-limit)
PRIMARY="https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf"
FALLBACK="https://cdn.jsdelivr.net/gh/JetBrains/JetBrainsMono@master/fonts/ttf"

WEIGHTS=(
  "JetBrainsMono-Regular"
  "JetBrainsMono-Medium"
  "JetBrainsMono-SemiBold"
  "JetBrainsMono-Bold"
)

download_font() {
  local name="$1"
  local dest="$FONT_DIR/${name}.ttf"

  if [[ -f "$dest" ]]; then
    echo "  ✔  ${name}.ttf already exists, skipping."
    return 0
  fi

  echo "  ↓  Downloading ${name}.ttf …"

  # Try primary (GitHub) with 3 retries
  if curl -fsSL --retry 3 --retry-delay 2 --max-time 30 \
      "${PRIMARY}/${name}.ttf" -o "$dest" 2>/dev/null; then
    echo "  ✔  Saved to $dest  (GitHub)"
    return 0
  fi

  echo "  ⚠  GitHub timed out, trying jsDelivr mirror…"

  # Fallback to jsDelivr CDN
  if curl -fsSL --retry 3 --retry-delay 2 --max-time 30 \
      "${FALLBACK}/${name}.ttf" -o "$dest" 2>/dev/null; then
    echo "  ✔  Saved to $dest  (jsDelivr)"
    return 0
  fi

  echo "  ✗  FAILED: ${name}.ttf — check your internet connection and retry."
  return 1
}

echo "── Downloading JetBrains Mono ──"
FAILED=0
for name in "${WEIGHTS[@]}"; do
  download_font "$name" || FAILED=$((FAILED + 1))
done

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "✔ All fonts downloaded. Run: flutter pub get"
else
  echo "✗ $FAILED font(s) failed. Re-run this script to retry."
  exit 1
fi
