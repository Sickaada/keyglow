#!/bin/bash
# Builds KeyGlow.app (universal: Apple silicon + Intel). Needs Xcode command line tools.
#   ./build.sh            -> KeyGlow.app next to this script
#   ./build.sh --zip      -> also KeyGlow.zip for a release
set -euo pipefail
cd "$(dirname "$0")"

APP=KeyGlow.app
BIN="$APP/Contents/MacOS/KeyGlow"
rm -rf "$APP" .build && mkdir -p "$APP/Contents/MacOS" .build

for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target "$arch-apple-macos14.0" KeyGlow.swift Panel.swift -o ".build/KeyGlow-$arch"
done
lipo -create .build/KeyGlow-arm64 .build/KeyGlow-x86_64 -output "$BIN"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.sickaada.keyglow</string>
    <key>CFBundleName</key><string>KeyGlow</string>
    <key>CFBundleDisplayName</key><string>KeyGlow</string>
    <key>CFBundleExecutable</key><string>KeyGlow</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: macOS permissions attach to KeyGlow itself. (Not notarized.)
codesign --force --sign - --identifier io.github.sickaada.keyglow "$APP"
echo "Built $(pwd)/$APP"

if [[ "${1:-}" == "--zip" ]]; then
  rm -f KeyGlow.zip && ditto -c -k --keepParent "$APP" KeyGlow.zip
  echo "Zipped $(pwd)/KeyGlow.zip"
fi
