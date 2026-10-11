# Contributing to NEXUS

Thanks for checking out NEXUS — EvoHacks 2026 entry (theme: AI for Automation).

## Ground rules

- **Security**: never commit keys, tokens, or developer passwords.
- **Style**: Swift 6 conventions where the build requires them (both targets
  build warning-free — keep it that way). UI follows a state-driven model:
  no timers driving visual state directly, every transition animates on
  state changes, respect Reduce Motion.
- **Commits**: small, conventional prefix (`rooms:`, `automation:`, `fix:`,
  `docs:` …).

## Building

Requires macOS 14+ with Xcode or Command Line Tools.

```bash
# Main app + installer target
swift build -c release

# Red Triangle companion
swiftc -swift-version 5 -O NexusTriangle/main.swift -o /tmp/triangle
```

## Installing locally

```bash
bash install.sh        # or double-click NEXUS Installer.app
```

Installs universal binaries into `/Applications`, signs them, and sets up
the demo fixture. See `nexus-setup.sh` for details.

## Adding a lens skill (Triangle)

1. Add a route branch in `route()` in `NexusTriangle/main.swift`.
2. Update `showHelp()`.
3. Make sure failures respond in `blocked` state — the triangle shakes and
   the bridge logs `bridge.jsonl` so NEXUS.app can show it in Events.

## Releases

`make-installer-app.sh` regenerates `NEXUS Installer.app` — it embeds a
snapshot of the package so the .app is fully self-contained.
