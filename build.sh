#!/bin/bash
# Build "La Régie.app" — a self-contained macOS menu-bar scene orchestrator.
# No Xcode project: swiftc-compiled, hand-assembled bundle, ad-hoc signed.
#
#   ./build.sh            build + selftest, leave the .app in build/
#   ./build.sh install    build, then replace the /Applications copy and launch
#   ./build.sh selftest   build, run the headless selftest only
#
# Source lives outside iCloud (~/Claude/apps), but we still COMPILE to /tmp and
# strip xattrs before signing — the safe Atelier habit that keeps codesign happy.
set -euo pipefail
cd "$(dirname "$0")"

NAME="La Régie"        # bundle / display name (accented — what Jac sees)
BIN="LaRegie"           # executable name: ASCII only, because codesign chokes
                        # on a non-ASCII (é) Mach-O filename. Must match
                        # CFBundleExecutable in Info.plist.
TARGET="arm64-apple-macos14.0"
WORK="/tmp/la-regie-build"
APP="$WORK/$NAME.app"

echo "→ Cleaning"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "→ Compiling $NAME (Swift, arm64, macOS 14+)"
swiftc -O -target "$TARGET" -swift-version 5 \
  Sources/main.swift \
  Sources/Loc.swift \
  Sources/KeyCombo.swift \
  Sources/HotkeyManager.swift \
  Sources/Model.swift \
  Sources/AudioOutput.swift \
  Sources/InstalledApps.swift \
  Sources/Shortcuts.swift \
  Sources/Engine.swift \
  Sources/HUD.swift \
  Sources/Store.swift \
  Sources/Theme.swift \
  Sources/HotkeyRecorder.swift \
  Sources/EditorView.swift \
  Sources/ActionRow.swift \
  Sources/AppDelegate.swift \
  Sources/SelfTest.swift \
  -o "$WORK/$BIN" \
  -framework AppKit -framework SwiftUI -framework CoreAudio \
  -framework AudioToolbox -framework Carbon -framework UniformTypeIdentifiers

echo "→ Self-test (logic sanity, no destructive actions)"
"$WORK/$BIN" selftest

if [ "${1:-}" = "selftest" ]; then
  echo "✓ Selftest complete."
  exit 0
fi

echo "→ Bundling $NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$WORK/$BIN" "$APP/Contents/MacOS/$BIN"
cp Info.plist    "$APP/Contents/Info.plist"
if [ -f "La Régie.icns" ]; then cp "La Régie.icns" "$APP/Contents/Resources/"; fi
for L in fr en; do
  if [ -d "Resources/$L.lproj" ]; then
    mkdir -p "$APP/Contents/Resources/$L.lproj"
    cp Resources/$L.lproj/*.strings "$APP/Contents/Resources/$L.lproj/" 2>/dev/null || true
  fi
done
chmod +x "$APP/Contents/MacOS/$BIN"

echo "→ Linting Info.plist"
plutil -lint "$APP/Contents/Info.plist"

echo "→ Ad-hoc code signing"
xattr -cr "$APP" 2>/dev/null || true
# Single self-contained binary, no nested code → no --deep needed (and --deep can
# bus-error on some macOS builds). Sign the bundle directly.
codesign --force --sign - "$APP" && echo "  signed" || echo "  (skipped — runs locally regardless)"
codesign -v "$APP" && echo "  codesign -v: valid" || true

# Copy the finished bundle next to the repo.
rm -rf "build"
mkdir -p "build"
ditto "$APP" "build/$NAME.app"
echo "✓ Built build/$NAME.app"

if [ "${1:-}" = "install" ]; then
  DEST="/Applications/$NAME.app"
  echo "→ Installing to $DEST"
  pkill -f "/Applications/$NAME.app" 2>/dev/null || true
  sleep 1
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  xattr -cr "$DEST" 2>/dev/null || true
  codesign --force --sign - "$DEST" && echo "  signed in place" || true
  open "$DEST"
  echo "✓ Installed & launched $DEST  (look for the ▤ slider glyph in your menu bar)"
else
  echo "  Run it with:  open \"build/$NAME.app\"   (look for the slider glyph in your menu bar)"
  echo "  Or install over the /Applications copy:  ./build.sh install"
fi
