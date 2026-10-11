#!/usr/bin/env bash
# make-installer-app.sh — bundles the full NEXUS package into "NEXUS Installer.app"
# The .app is self-contained: double-click on any Mac → Terminal runs the wizard.
set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$PKG/NEXUS Installer.app"

echo "▸ Assembling NEXUS Installer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/package"

# copy the whole shippable package (no build artifacts, no installer app itself)
rsync -a \
  --exclude .build \
  --exclude .DS_Store \
  --exclude .git \
  --exclude "NEXUS Installer.app" \
  --exclude .nexus-copy \
  "$PKG/Package.swift" "$PKG/README.md" "$PKG/LICENSE" "$PKG/CONTRIBUTING.md" \
  "$PKG/install.sh" "$PKG/nexus-setup.sh" \
  "$PKG/Sources" "$PKG/NexusTriangle" "$PKG/NEXUSHelper" "$PKG/FixturePackage" "$PKG/scripts" \
  "$APP/Contents/Resources/package/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>NEXUS Installer</string>
    <key>CFBundleIdentifier</key><string>com.nexus.installer</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>NEXUS Installer</string>
    <key>CFBundleDisplayName</key><string>NEXUS Installer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>NexusTri</string>
</dict>
</plist>
PLIST

if [ -f "$PKG/scripts/NexusTri.icns" ]; then
  cp "$PKG/scripts/NexusTri.icns" "$APP/Contents/Resources/NexusTri.icns"
fi

cat > "$APP/Contents/MacOS/NEXUS Installer" <<'LAUNCH'
#!/bin/bash
RES="$(cd "$(dirname "$0")/../Resources/package" && pwd)"
osascript <<EOF
tell application "Terminal"
    activate
    do script "clear; echo '── NEXUS Installer ──'; cd \"$RES\" && chmod +x nexus-setup.sh install.sh && ./nexus-setup.sh; echo; echo '── install finished ──'"
end tell
EOF
LAUNCH
chmod +x "$APP/Contents/MacOS/NEXUS Installer"
codesign --force --sign - "$APP" 2>/dev/null || true

echo "  ✓ $APP"
echo "  ✓ package embedded ($(du -sh "$APP/Contents/Resources/package" | cut -f1) total)"
echo "  Drag it anywhere — double-click installs everything."
