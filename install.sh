#!/usr/bin/env bash
# install.sh - minimal NEXUS installer for EvoHacks 2026
#usage: ./install.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SCORE[0]}")" && pwd)"
OLLAMA_CLI=