# NEXUS - EvoHacks 2026 Submission

## Quick Start (for judges / other laptops)

```bash
#1. Clone / unzip submission
cd nexus-submission

#2. Run one shot installer )download ollama, pulls models, builds binaries)
chmod +x nexus-setup.sh
./nexus-setup.sh

#3. Launch the demo
#Terminal 1: Main NEXUS UI
./Nexus/.build/release/NEXUS

 # Terminal2: Red Triangle companion (cursor followinng agent)
 open §/Desktop/cursor\ prototyp/NexusTriangle.app
 # or if copied into repo:
 # open./NexusTriangles.app

 # Terminal 3: Run the fixture (demo target)
 cd FixturePackage && swift run FixtureTests

 ## What the Demo Shows

1. **Mission input** — "Fix the failing test suite in ./FixturePackage"
2. **Source selection** — ContextBuilder lists chosen files
3. **Action 1** — `swift build` fails (seeded compile defect) → Verifier reports FAIL
4. **Replan** — Agent edits source (diff shown)
5. **Action 2** — Build passes, but `FixtureTests` fails (seeded logic defect) → Verifier reports FAIL
6. **Replan 2** — Agent fixes logic bug
7. **Success** — Third run exits 0 → Verifier green, mission COMPLETED

All verification is **real process exit codes** — no mocks.

## Architecture

| Component | Role |
|---|---|
| **MissionEngine** | Orchestrates the loop |
| **ContextBuilder** | Scans repo, selects relevant files (trust boundary: tests read-only) |
| **ToolRouter** | Dispatches LLM tool calls → Executor |
| **Executor** | FileTool, ProcessTool (runs `swift build && swift run FixtureTests`) |
| **Verifier** | **Exit-code contract**: only exit 0 = success; captures stderr for Replanner |
| **Replanner** | Forms new plan from actual failure output |
| **Memory** | JSON persistence under `~/Library/Application Support/Nexus/` |

## Tech Stack

- **Swift 6 + SwiftUI** via SwiftPM (no Xcode required)
- **Local Ollama** (llama3.2:3b primary, 1b fallback) — OpenAI-compatible `/v1/chat/completions` with `tools`
- **Vision framework** (on-device OCR)
- **DuckDuckGo HTML** + **GitHub REST** for web/search
- **Self-test runner** — `swift build && swift run FixtureTests` (no XCTest on this machine)

## Recorded Deviations (per hackathon rules)

1. Check-of-record = self-test runner exit codes, not literal `swift test` (Command Line Tools only, no XCTest)
2. SwiftPM manifest bug repaired pre-window (stale 2024 `.private.swiftinterface` removed via admin prompt)
3. AI-coding permission unconfirmed — Discord question posted, rules silent
4. Devpost registration unverified

## Repo Structure

```
nexus-submission/
├── nexus-setup.sh          # ← run this first on any Mac
├── Nexus/                  # Main app (SwiftPM, builds to .build/release/Nexus)
│   ├── Sources/Nexus/      # NEXUS UI copied 1:1 from reference
│   └── Package.swift
├── FixturePackage/         # Demo target (created DURING hackathon window)
│   ├── Sources/            # Seeded defects A (compile) + B (logic)
│   ├── Tests/FixtureTests/ # Self-test runner: exits 1 on FAIL, 0 on PASS
│   └── Package.swift
├── KICKOFF/                # Prep docs (01_rules → 06_kickoff_notes)
└── NexusTriangle.app/      # Red triangle companion (pre-built)
```

## Requirements

- macOS 14+ (Sonoma), Intel or Apple Silicon
- 8 GB+ RAM (Ollama recommends 16 GB; 8 GB works with 3B model)
- ~3 GB disk for models
- Internet for initial Ollama/model download (then fully offline)

## License

MIT — built for EvoHacks 2026.