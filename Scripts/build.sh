#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/OpenBSM.app"
CONTENTS_DIR="$APP_DIR/Contents"
ARCH="${OPENBSM_ARCH:-arm64}"
TARGET_TRIPLE="${ARCH}-apple-macosx"

cd "$ROOT_DIR"
swift build -c release --arch "$ARCH"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_DIR/$TARGET_TRIPLE/release/OpenBSMInputMethod" "$CONTENTS_DIR/MacOS/"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/bsm.txt" "$CONTENTS_DIR/Resources/bsm.txt"
sips --setProperty format tiff "$ROOT_DIR/Resources/OpenBSM-InputMenu.svg" \
  --out "$CONTENTS_DIR/Resources/OpenBSM-InputMenu.tiff" >/dev/null

codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"
