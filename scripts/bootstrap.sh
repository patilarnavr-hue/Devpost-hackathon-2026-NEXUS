#!/usr/bin/env bash
# bootstrap.sh — one-line install for any Mac:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS/main/scripts/bootstrap.sh)"
set -euo pipefail

REPO="https://github.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS.git"
DIR="${NEXUS_HOME:-$HOME/.nexus-src}"

say() { printf '\033[1;31m▲\033[0m %s\n' "$*"; }

if [ -d "$DIR/.git" ]; then
  say "Updating existing clone at $DIR"
  git -C "$DIR" pull --ff-only
else
  say "Cloning NEXUS into $DIR"
  git clone --depth 1 "$REPO" "$DIR"
fi

say "Running installer (builds universal binaries, installs to /Applications)"
cd "$DIR"
bash install.sh

say "Done. NEXUS.app + NexusTriangle.app are in /Applications."
