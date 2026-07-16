#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/OpenBSM.app"
PKG_DIR="$BUILD_DIR/pkg"
PAYLOAD_DIR="$PKG_DIR/payload"
COMPONENT_PKG="$PKG_DIR/OpenBSM-component.pkg"
PRODUCT_PKG="$BUILD_DIR/OpenBSM.pkg"
PACKAGE_ID="dev.openbsm.inputmethod.OpenBSM.pkg"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")

"$ROOT_DIR/Scripts/build.sh"

rm -rf "$PKG_DIR" "$PRODUCT_PKG"
mkdir -p "$PAYLOAD_DIR/Library/Input Methods"
ditto "$APP_DIR" "$PAYLOAD_DIR/Library/Input Methods/OpenBSM.app"

pkgbuild \
  --root "$PAYLOAD_DIR" \
  --identifier "$PACKAGE_ID" \
  --version "$VERSION" \
  --install-location / \
  --component-plist "$ROOT_DIR/Packaging/component.plist" \
  --scripts "$ROOT_DIR/Packaging/Scripts" \
  "$COMPONENT_PKG"

productbuild \
  --package "$COMPONENT_PKG" \
  --identifier "$PACKAGE_ID" \
  --version "$VERSION" \
  "$PRODUCT_PKG"

echo "Packaged $PRODUCT_PKG"
