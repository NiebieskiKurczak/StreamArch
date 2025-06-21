#!/bin/bash
set -e

# === CONFIGURATION ===
PROFILE_DIR="$(pwd)"
OUTPUT_DIR="$PROFILE_DIR/out"

# === CHECK DEPENDENCIES ===
command -v mkarchiso >/dev/null 2>&1 || {
    echo >&2 "mkarchiso not found. Install it with: sudo pacman -S archiso";
    exit 1;
}

# === CLEAN WORK DIR ===
if [ -d "$PROFILE_DIR/work" ]; then
  echo "Removing previous work directory..."
  sudo rm -rf "$PROFILE_DIR/work"
fi

# === CREATE OUTPUT DIR ===
mkdir -p "$OUTPUT_DIR"

# === BUILD ISO ===
echo "📦 Building ISO from profile at: $PROFILE_DIR"
sudo mkarchiso -v -o "$OUTPUT_DIR" "$PROFILE_DIR"

echo "✅ ISO built successfully. Check the output in: $OUTPUT_DIR"
