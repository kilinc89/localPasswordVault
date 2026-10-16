#!/usr/bin/env bash
# Builds LocalVault.app (release) and packages it as dist/LocalVault.dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LocalVault"
VERSION="1.0.0"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT"
echo "==> swift build (release, universal)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

echo "==> .app paketi"
rm -rf "$BUILD_DIR" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.baltechventures.localvault</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Yerel parola yöneticisi — veriler yalnızca bu Mac'te.</string>
</dict>
</plist>
PLIST

echo "==> simge"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/make_icon.swift" "$BUILD_DIR/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> ad-hoc imza"
codesign --force --deep --sign - --options runtime "$APP"
codesign --verify --strict "$APP"

echo "==> DMG"
mkdir -p "$DIST_DIR"
STAGE="$BUILD_DIR/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DIST_DIR/$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST_DIR/$APP_NAME.dmg" >/dev/null
hdiutil verify "$DIST_DIR/$APP_NAME.dmg" >/dev/null
echo "==> Hazır: $DIST_DIR/$APP_NAME.dmg"
