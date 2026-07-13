#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
SOURCE_APP="$ROOT_DIR/.build/OpenBSM.app"
INSTALL_DIR="$HOME/Library/Input Methods"

"$ROOT_DIR/Scripts/build.sh"
mkdir -p "$INSTALL_DIR"
ditto "$SOURCE_APP" "$INSTALL_DIR/OpenBSM.app"

echo "Installed OpenBSM for the current user. Log out and log in again to enable it."
