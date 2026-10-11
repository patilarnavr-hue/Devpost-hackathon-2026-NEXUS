#!/usr/bin/env bash
# install.sh — thin wrapper; the installer is nexus-setup.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nexus-setup.sh" "$@"
