#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="$ROOT/.build/$CONFIGURATION"
APP_NAME="Copyas"
APP_PATH="$ROOT/dist/$APP_NAME.app"
BINARY_SOURCE="$BUILD_DIR/CopyasMenuBar"
BINARY_DEST="$APP_PATH/Contents/MacOS/$APP_NAME"

if [[ -n "${COPYAS_VERSION:-}" ]]; then
  VERSION="$COPYAS_VERSION"
else
  VERSION="$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/Copyas/CopyasMetadata.swift | head -n 1)"
fi

if [[ -z "$VERSION" ]]; then
  echo "error: could not determine Copyas version" >&2
  exit 1
fi

echo "Building CopyasMenuBar ($CONFIGURATION)..."
swift build -c "$CONFIGURATION" --product CopyasMenuBar -Xswiftc -warnings-as-errors

if [[ ! -f "$BINARY_SOURCE" ]]; then
  echo "error: built binary not found at $BINARY_SOURCE" >&2
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Copyas</string>
  <key>CFBundleExecutable</key>
  <string>Copyas</string>
  <key>CFBundleIdentifier</key>
  <string>com.joshmcarthur.copyas</string>
  <key>CFBundleName</key>
  <string>Copyas</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSUserNotificationUsageDescription</key>
  <string>Copyas notifies you when clipboard text has been transformed.</string>
</dict>
</plist>
PLIST

cp "$BINARY_SOURCE" "$BINARY_DEST"
chmod +x "$BINARY_DEST"

echo "Signing $APP_PATH..."
codesign --force --deep -s - "$APP_PATH"

echo "Built $APP_PATH"
