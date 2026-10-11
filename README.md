# NEXUS — EvoHacks 2026 (AI for Automation)

Mission-first macOS intelligence with a **Red Triangle companion**: a genie
cursor that lives on your Mac, learns chores, and executes them. Fully local
— the brain is Ollama on your machine. No cloud, no accounts.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black) ![License: MIT](https://img.shields.io/badge/license-MIT-red)

## Install (any Mac, one line)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS/main/scripts/bootstrap.sh)"
```

**Or** double-click **NEXUS Installer.app** from this repo (self-contained —
drag it anywhere, no internet repo needed).

**Or** clone and run:

```bash
git clone https://github.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS.git
cd Devpost-hackathon-2026-NEXUS && bash install.sh
```

The installer handles everything:

| Piece | What you get |
|---|---|
| **NEXUS.app** | Main mission UI (universal arm64+x86_64) → /Applications + Desktop |
| **NexusTriangle.app** | Menu-bar companion: lens, TEACH, skills, agent (universal) |
| **Ollama + llama3.2** | Local brain, installed/pulled automatically |
| **FixturePackage** | Demo target → ~/Documents (Verifier's check-of-record) |
| **Signing** | Stable identity — Accessibility grant survives updates |
| **Launch at login** | Triangle starts with macOS |

One-time: grant **Accessibility** when macOS asks (the installer opens the pane).

## Try it

**NEXUS.app** — mission input:
> *"Fix the failing test suite in ~/Documents/FixturePackage"*

The triangle executes step-by-step (click, type, scroll, verify), the shell
animates every state change, and the verifier seals success with proof.

**Triangle** (⌥Space opens the lens):
- `help` — full command list
- `run ls` · `rename a to b` · `find report` · agent mode for anything else
- `watch downloads` · `every day at 9am do coffee` · `chain coffee, backup, email`
- `record demo` → do a chore → `stop` → `replay demo`

**Rooms tab** — LAN collaboration: create a room, share the 4-char code (or
`nexus://room/CODE` link), chat + shared mission board with anyone on your
network. Purely local mesh over Bonjour.

## Package contents

```
├── NEXUS Installer.app   # double-click installer (package embedded)
├── install.sh            # thin wrapper → nexus-setup.sh
├── scripts/bootstrap.sh  # one-line remote install (see above)
├── scripts/make-icon.swift, NexusTri.icns
├── nexus-setup.sh        # universal build + install + sign
├── make-installer-app.sh # regenerates NEXUS Installer.app
├── Package.swift         # NEXUS + installer targets
├── Sources/Nexus/        # main app (SwiftUI, samaritan-style)
├── Sources/NexusInstaller/
├── NexusTriangle/main.swift
├── FixturePackage/       # seeded defects for the demo mission
└── .github/workflows/    # CI: both targets build warning-free
```

Requirements: macOS 14+, ~3 GB disk for the model, internet for first install only.

## Architecture

```
NEXUS.app  ──bridge.jsonl──►  Events feed        (every receipt/receipt streams in)
NexusTriangle (Intents + AX + CG events)  ──►  Ollama llama3.2 (local)
       │
       ├── Skills: deterministic verbs (run, rename, find, replay…)
       ├── Agent:  autonomous loop — observe → plan → act → verify
       └── Automation: schedules · folder watchers · chore chains · rooms
```

Local state lives in `~/Library/Application Support/Nexus/`
(`bridge.jsonl`, `schedules.json`, `watches.json`, `rooms/`).

## License

MIT — see [LICENSE](LICENSE). Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
