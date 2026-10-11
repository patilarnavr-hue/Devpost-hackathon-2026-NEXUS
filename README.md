# NEXUS v3 — EvoHacks 2026

Mission-first macOS intelligence + a Red Triangle companion that learns chores.

## Install (any Mac)

**Easiest:** double-click **NEXUS Installer.app** (self-contained — drag it anywhere).

**Or from terminal:**
```bash
chmod +x nexus-setup.sh
./nexus-setup.sh
```

Installs everything and works out of the box:

| Piece | What you get |
|---|---|
| **NEXUS.app** | Main mission UI (universal arm64+x86_64), Desktop + /Applications |
| **NexusTriangle.app** | Menu-bar companion: lens, TEACH, skills, agent (universal) |
| **Ollama + llama3.2:3b** | Local brain, installed/pulled automatically |
| **FixturePackage** | Demo target → ~/Documents (Verifier's check-of-record) |
| **Signing** | Stable identity created — Accessibility grant survives updates |
| **Launch at login** | Triangle starts with macOS |

One-time: grant **Accessibility** when macOS asks (installer opens the pane).

## Try it

- **NEXUS.app** (Desktop): mission input → "Fix the failing test suite in ~/Documents/FixturePackage"
- **Triangle** (⌥Space): `help` · `run ls` · `rename a to b` · `record demo` → do a chore → `stop` → `replay demo`
- **Chat** (⌃⌥C): ask anything, fully offline

## Package contents

```
nexus v3/
├── NEXUS Installer.app   # double-click installer (package embedded)
├── nexus-setup.sh        # or run this from terminal
├── make-installer-app.sh # regenerates the installer .app
├── Package.swift         # NEXUS + installer app targets
├── Sources/Nexus/        # main app (SwiftUI, samaritan-style, no face lock)
├── Sources/NexusInstaller/
├── NexusTriangle/main.swift
└── FixturePackage/       # seeded defects for the demo mission
```

Requirements: macOS 14+, ~3 GB disk for the model, internet for first install only.
