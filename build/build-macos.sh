#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="ZoomUpdate"
VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION//[^0-9.]/}"
BUNDLE="${APP_NAME}.app"
OUT="build/out"
ICONSET="build/AppIcon.iconset"
STAGE="build/pkgroot"
IDENTITY="${SIGN_IDENTITY:-}"
INSTALLER_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"

rm -rf "$OUT" "$ICONSET" "$STAGE" "$BUNDLE"
mkdir -p "$OUT" "$ICONSET" "$STAGE/Applications"

echo "==> Compiling run-only applet"
osacompile -x -o "$BUNDLE" zoom-update-microsoft.scpt

echo "==> Building icon"
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
            "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" icon/icon.png --out "$ICONSET/$2.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o build/AppIcon.icns
cp build/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
rm -f "$BUNDLE/Contents/Resources/applet.icns"

echo "==> Writing Info.plist"
PLIST="$BUNDLE/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
set_key() {
  "$PB" -c "Set :$1 $2" "$PLIST" 2>/dev/null || "$PB" -c "Add :$1 string $2" "$PLIST"
}
set_bool() {
  "$PB" -c "Set :$1 $2" "$PLIST" 2>/dev/null || "$PB" -c "Add :$1 bool $2" "$PLIST"
}
set_key CFBundleName "$APP_NAME"
set_key CFBundleDisplayName "Zoom Update"
set_key CFBundleIdentifier "com.zoom.update"
set_key CFBundleVersion "$VERSION"
set_key CFBundleShortVersionString "$VERSION"
set_key CFBundleIconFile "AppIcon"
set_key LSMinimumSystemVersion "10.15"
set_bool NSHighResolutionCapable true
set_bool LSUIElement true
set_key NSAppleEventsUsageDescription "Zoom Update uses System Events to add itself to login items."
set_key NSHumanReadableCopyright "Zoom Private client wrapper"

echo "==> Codesigning"
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$BUNDLE"
else
  codesign --force --deep --sign - "$BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$BUNDLE"
plutil -lint "$PLIST"

echo "==> Packaging zip"
ditto -c -k --keepParent "$BUNDLE" "$OUT/${APP_NAME}-${VERSION}.zip"

echo "==> Building installer package"
cp -R "$BUNDLE" "$STAGE/Applications/"
chmod +x pkg/scripts/*
pkgbuild --root "$STAGE" \
  --identifier "com.zoom.update.pkg" \
  --version "$VERSION" \
  --install-location "/" \
  --scripts pkg/scripts \
  --ownership recommended \
  "$OUT/${APP_NAME}-component.pkg"
sed "s/@VERSION@/$VERSION/g" pkg/distribution.xml > build/distribution.xml
productbuild --distribution build/distribution.xml \
  --package-path "$OUT" \
  "$OUT/${APP_NAME}-${VERSION}.pkg"
rm -f "$OUT/${APP_NAME}-component.pkg"

if [ -n "$INSTALLER_IDENTITY" ]; then
  productsign --sign "$INSTALLER_IDENTITY" "$OUT/${APP_NAME}-${VERSION}.pkg" "$OUT/${APP_NAME}-${VERSION}-signed.pkg"
  mv "$OUT/${APP_NAME}-${VERSION}-signed.pkg" "$OUT/${APP_NAME}-${VERSION}.pkg"
fi

pkgutil --payload-files "$OUT/${APP_NAME}-${VERSION}.pkg" >/dev/null

echo "==> Checksums"
( cd "$OUT" && shasum -a 256 ./* > SHA256SUMS )

echo "==> Done"
ls -lh "$OUT"
