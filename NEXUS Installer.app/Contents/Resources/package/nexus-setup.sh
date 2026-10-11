#!/usr/bin/env bash
# nexus-setup.sh — one-shot NEXUS installer (fully self-contained package)
# Installs: NEXUS.app (universal), Red Triangle companion (universal),
#           Ollama + llama3.2:3b, demo FixturePackage, Desktop shortcut,
#           launch-at-login. Safe to re-run.
# usage: ./nexus-setup.sh

set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRI_DST="/Applications/NexusTriangle.app"
NEXUS_DST="/Applications/NEXUS.app"
HELPER_DST="/Applications/NEXUS Helper.app"
KEYCHAIN="$HOME/Library/Keychains/nexus-sign.keychain-db"
KEYCHAIN_NAME="nexus-sign.keychain"
KEYCHAIN_PW="nexus"
SIGN_ID="NexusAgent Dev"
MODEL="llama3.2:3b"
PLIST="$HOME/Library/LaunchAgents/com.nexus.triangle.plist"

step() { printf '\n\033[1;31m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m•\033[0m %s\n' "$*"; }

sign_app() {
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    codesign --force --sign "$SIGN_ID" --keychain "$KEYCHAIN" "$1"
  else
    codesign --force --sign - "$1"
  fi
}

# ── prerequisites ──
step "Checking prerequisites"
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools missing — install them, then re-run this script"
  xcode-select --install || true
  exit 1
fi
ok "Command Line Tools present"
MAJ="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJ" -lt 14 ]; then
  warn "macOS 14+ required (found $(sw_vers -productVersion))"
  exit 1
fi
ok "macOS $(sw_vers -productVersion)"

# ── Ollama + model ──
step "Installing Ollama"
server_up() { curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; }
if server_up; then
  ok "Ollama server already running"
elif [ -d "/Applications/Ollama.app" ]; then
  open -g /Applications/Ollama.app
  ok "Launching Ollama.app…"
elif command -v ollama >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama.log 2>&1 &
  ok "Starting ollama serve…"
else
  warn "Installing Ollama via official installer (may prompt for your password)…"
  curl -fsSL https://ollama.com/install.sh | sh
  if command -v ollama >/dev/null 2>&1; then
    nohup ollama serve >/tmp/ollama.log 2>&1 &
  elif [ -d "/Applications/Ollama.app" ]; then
    open -g /Applications/Ollama.app
  fi
fi
for _ in $(seq 1 20); do server_up && break; sleep 1; done
if server_up; then
  ok "Ollama server running"
else
  warn "Ollama did not start — open Ollama.app once, then re-run this script"
  exit 1
fi

step "Pulling $MODEL (chat + agent brain)"
if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -q "llama3.2:3b"; then
  ok "Model already present"
else
  curl -sf http://localhost:11434/api/pull -d "{\"name\":\"$MODEL\"}" >/dev/null || warn "model pull slow/interrupted — re-run to resume"
  ok "Model pulled"
fi

# ── signing identity (stable — TCC grants survive updates) ──
step "Signing identity (grants survive rebuilds)"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  ok "Signing identity already present"
else
  TMPD="$(mktemp -d)"
  openssl req -x509 -newkey rsa:2048 -keyout "$TMPD/k.key" -out "$TMPD/k.crt" -days 3650 -nodes \
    -subj "/CN=$SIGN_ID" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign" 2>/dev/null
  openssl pkcs12 -export -inkey "$TMPD/k.key" -in "$TMPD/k.crt" -out "$TMPD/k.p12" \
    -passout pass:"$KEYCHAIN_PW" 2>/dev/null
  security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN_NAME" 2>/dev/null || true
  security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN" 2>/dev/null || true
  security set-keychain-settings -lut 21600 "$KEYCHAIN" 2>/dev/null || true
  security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"') 2>/dev/null || true
  security import "$TMPD/k.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PW" -T /usr/bin/codesign 2>/dev/null
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMPD/k.crt" 2>/dev/null || true
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" 2>/dev/null || true
  rm -rf "$TMPD"
  security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID" \
    && ok "Signing identity created" \
    || warn "Signing identity failed — falling back to ad-hoc (re-grant Accessibility after each update)"
fi

# ── Red Triangle (universal swiftc build) ──
step "Building Red Triangle — universal (arm64 + x86_64)"
TRI_SRC="$PKG/NexusTriangle/main.swift"
if [ ! -f "$TRI_SRC" ]; then
  warn "NexusTriangle/main.swift missing from package"
  exit 1
fi
NAT_ARCH="$(uname -m)"
if [ "$NAT_ARCH" = "arm64" ]; then OTHER_ARCH="x86_64"; else OTHER_ARCH="arm64"; fi
TMPU="$(mktemp -d)"
swiftc -swift-version 5 -O -target "$NAT_ARCH-apple-macos14.0" "$TRI_SRC" -o "$TMPU/tri-$NAT_ARCH"
swiftc -swift-version 5 -O -target "$OTHER_ARCH-apple-macos14.0" "$TRI_SRC" -o "$TMPU/tri-$OTHER_ARCH"
lipo -create "$TMPU/tri-$NAT_ARCH" "$TMPU/tri-$OTHER_ARCH" -output "$TMPU/NexusTriangle"
lipo -info "$TMPU/NexusTriangle" 2>/dev/null | sed 's/^/  /' || true

mkdir -p "$TRI_DST/Contents/MacOS"
cat > "$TRI_DST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>NexusTriangle</string>
    <key>CFBundleIdentifier</key><string>com.nexus.triangle</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>NexusTriangle</string>
    <key>CFBundleDisplayName</key><string>Nexus Triangle</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>NexusTriangle</string>
</dict>
</plist>
PLIST
cp "$TMPU/NexusTriangle" "$TRI_DST/Contents/MacOS/NexusTriangle"
mkdir -p "$TRI_DST/Contents/Resources"
if [ -f "$PKG/scripts/NexusTri.icns" ]; then
  cp "$PKG/scripts/NexusTri.icns" "$TRI_DST/Contents/Resources/NexusTriangle.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string NexusTriangle" "$TRI_DST/Contents/Info.plist" 2>/dev/null || true
fi
sign_app "$TRI_DST"
ok "Installed: $TRI_DST"

# ── NEXUS main app (universal swift build) ──
step "Building NEXUS — universal (arm64 + x86_64)"
(cd "$PKG" && swift build -c release)
cp "$PKG/.build/release/Nexus" "$TMPU/Nexus-$NAT_ARCH"
(cd "$PKG" && swift build -c release -Xswiftc -target -Xswiftc "$OTHER_ARCH-apple-macos14.0")
cp "$PKG/.build/release/Nexus" "$TMPU/Nexus-$OTHER_ARCH"
lipo -create "$TMPU/Nexus-$NAT_ARCH" "$TMPU/Nexus-$OTHER_ARCH" -output "$TMPU/Nexus"
lipo -info "$TMPU/Nexus" 2>/dev/null | sed 's/^/  /' || true

mkdir -p "$NEXUS_DST/Contents/MacOS" "$NEXUS_DST/Contents/Resources"
cp "$TMPU/Nexus" "$NEXUS_DST/Contents/MacOS/Nexus"
cat > "$NEXUS_DST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>Nexus</string>
    <key>CFBundleIdentifier</key><string>com.nexus.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>NEXUS</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>EvoHacks 2026 — AI for Automation</string>
    <key>NSLocalNetworkUsageDescription</key><string>NEXUS rooms use the local network to chat and collaborate — no cloud, no accounts.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_nexuscollab._tcp</string>
    </array>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>com.nexus.room</string>
            <key>CFBundleURLSchemes</key>
            <array><string>nexus</string></array>
        </dict>
    </array>
    <key>CFBundleIconFile</key><string>Nexus</string>
</dict>
</plist>
PLIST
if [ -f "$PKG/scripts/NexusTri.icns" ]; then
  cp "$PKG/scripts/NexusTri.icns" "$NEXUS_DST/Contents/Resources/Nexus.icns"
fi
sign_app "$NEXUS_DST"
rm -rf "$TMPU"
ok "Installed: $NEXUS_DST"

# ── NEXUS Helper (install assistant — same local Ollama brain) ──
HELPER_SRC="$PKG/NEXUSHelper/main.swift"
if [ -f "$HELPER_SRC" ]; then
  step "Building NEXUS Helper — universal (arm64 + x86_64)"
  TMPU="$(mktemp -d)"
  swiftc -swift-version 5 -O -target "$NAT_ARCH-apple-macos14.0" "$HELPER_SRC" -o "$TMPU/h-$NAT_ARCH"
  swiftc -swift-version 5 -O -target "$OTHER_ARCH-apple-macos14.0" "$HELPER_SRC" -o "$TMPU/h-$OTHER_ARCH"
  lipo -create "$TMPU/h-$NAT_ARCH" "$TMPU/h-$OTHER_ARCH" -output "$TMPU/NEXUS Helper"
  mkdir -p "$HELPER_DST/Contents/MacOS" "$HELPER_DST/Contents/Resources"
  cp "$TMPU/NEXUS Helper" "$HELPER_DST/Contents/MacOS/NEXUS Helper"
  [ -f "$PKG/scripts/NexusTri.icns" ] && cp "$PKG/scripts/NexusTri.icns" "$HELPER_DST/Contents/Resources/NexusTri.icns"
  cat > "$HELPER_DST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>NEXUS Helper</string>
    <key>CFBundleIdentifier</key><string>com.nexus.helper</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>NEXUS Helper</string>
    <key>CFBundleDisplayName</key><string>NEXUS Helper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>NexusTri</string>
</dict>
</plist>
PLIST
  sign_app "$HELPER_DST"
  defaults write com.nexus.helper nexus.src -string "$PKG"
  rm -rf "$TMPU"
  ok "Installed: $HELPER_DST"
fi

# ── demo fixture ──
step "Demo fixture (Verifier's check-of-record target)"
if [ -d "$PKG/FixturePackage" ]; then
  mkdir -p "$HOME/Documents"
  rsync -a --delete --exclude .build --exclude .DS_Store "$PKG/FixturePackage" "$HOME/Documents/FixturePackage"
  ok "FixturePackage → ~/Documents/FixturePackage"
else
  warn "FixturePackage missing from package — demo mission needs it"
fi

# ── Desktop shortcut ──
step "Desktop shortcut"
ln -sfn "$NEXUS_DST" "$HOME/Desktop/NEXUS.app"
ok "~/Desktop/NEXUS.app → $NEXUS_DST"

# ── launch at login (triangle) ──
step "Launch at login"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nexus.triangle</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TRI_DST/Contents/MacOS/NexusTriangle</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/com.nexus.triangle" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null \
  || launchctl load -w "$PLIST" 2>/dev/null \
  || true
ok "LaunchAgent installed (triangle starts with macOS)"

# ── launch ──
step "Starting NEXUS + Red Triangle"
pkill -x NexusTriangle 2>/dev/null || true
pkill -x Nexus 2>/dev/null || true
sleep 1
open "$TRI_DST"
open "$NEXUS_DST"
if [ -d "$HELPER_DST" ]; then
  pkill -f "NEXUS Helper" 2>/dev/null || true
  open "$HELPER_DST"
fi
sleep 1
ok "Running"

# ── permissions ──
step "Accessibility — one-time, macOS requires your click"
echo "  1 ▸ Menu bar ▸ ▲ (red triangle icon) ▸ Grant Accessibility…"
echo "  2 ▸ System Settings ▸ Privacy & Security ▸ Accessibility ▸ enable NexusTriangle"
echo "  The ⚠ in the menu bar disappears within seconds once granted."
echo "  (This grant sticks — the installer signs with a permanent identity.)"
echo "  Screen Recording (optional, for the 'screenshot' command) — macOS"
echo "  prompts automatically the first time you use it."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

printf '\n\033[1;31mDone — everything is installed.\033[0m\n'
echo "  NEXUS.app    Desktop + /Applications (main mission UI)"
echo "  ▲ triangle   menu bar — the companion"
echo "  NEXUS Helper  install assistant — ask it doctor / fix / reset / reinstall"
echo ""
echo "  Red Triangle lens (⌥Space):"
echo "    help                  all commands"
echo "    run <cmd>             shell with real exit code"
echo "    rename/move/copy/trash/mkdir/ls/cat/touch/open <path>"
echo "    record <name> · stop  TEACH a chore — replay <name> runs it"
echo "    agent <task>          AI drives the cursor"
echo "    ⌃⌥C                   quick chat"
