#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/OpenBSM.app"
DMG_ROOT="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/OpenBSM.dmg"

"$ROOT_DIR/Scripts/build.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
ditto "$APP_DIR" "$DMG_ROOT/OpenBSM.app"
cat > "$DMG_ROOT/README.txt" <<'EOF'
OpenBSM installation

1. Copy OpenBSM.app to:
   ~/Library/Input Methods/

2. Log out and log in again.

3. Open System Settings > Keyboard > Text Input > Edit, then add OpenBSM under Traditional Chinese.

This development DMG is ad-hoc signed. macOS may require manual approval in Privacy & Security before opening it.
EOF

hdiutil create \
  -volname "OpenBSM" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Packaged $DMG_PATH"
