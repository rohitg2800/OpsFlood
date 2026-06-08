#!/usr/bin/env bash
# =============================================================================
# scripts/download_fonts.sh
# Downloads JetBrains Mono OTF/TTF files into assets/fonts/
# Run once from the project root:  bash scripts/download_fonts.sh
# =============================================================================
set -euo pipefail

FONT_DIR="assets/fonts"
mkdir -p "$FONT_DIR"

BASE="https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf"

WEIGHTS=(
  "JetBrainsMono-Regular"
  "JetBrainsMono-Medium"
  "JetBrainsMono-SemiBold"
  "JetBrainsMono-Bold"
)

echo "── Downloading JetBrains Mono ──"
for name in "${WEIGHTS[@]}"; do
  dest="$FONT_DIR/${name}.ttf"
  if [[ -f "$dest" ]]; then
    echo "  ✔  $name already exists, skipping."
  else
    echo "  ↓  Downloading ${name}.ttf …"
    curl -fsSL "${BASE}/${name}.ttf" -o "$dest"
    echo "  ✔  Saved to $dest"
  fi
done

echo ""
echo "✔ Done. Run 'flutter pub get' to register the fonts."
