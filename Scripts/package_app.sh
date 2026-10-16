#!/bin/bash
# Build MoatBar.app from the Swift package: release build, app bundle with the
# resource bundle and Info.plist, ad-hoc signature. Output: ./MoatBar.app
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${MOATBAR_VERSION:-0.1.0}"
APP="MoatBar.app"

# Build with swiftc directly, without SwiftPM. Used when `swift build` can't
# read Package.swift: a Command Line Tools install whose compiler and SDK
# versions differ fails with "no such module 'PackageDescription'".
build_direct() {
    local out=".build/direct"
    local target
    target="$(uname -m)-apple-macos12"
    rm -rf "$out"
    mkdir -p "$out/ModuleCache"
    export CLANG_MODULE_CACHE_PATH="$PWD/$out/ModuleCache"
    local flags=(-O -target "$target" -module-cache-path "$PWD/$out/ModuleCache")
    swiftc "${flags[@]}" -parse-as-library -emit-library -static -emit-module \
        -module-name MoatBarCore -emit-module-path "$out/MoatBarCore.swiftmodule" \
        $(find Sources/MoatBarCore -name '*.swift') -o "$out/libMoatBarCore.a"
    swiftc "${flags[@]}" -I "$out" -L "$out" -lMoatBarCore -module-name MoatBar \
        $(find Sources/MoatBar -name '*.swift') -o "$out/MoatBar"
    BIN="$out"
}

if [ "${MOATBAR_DIRECT_BUILD:-0}" = "1" ]; then
    build_direct
elif swift build -c release --product MoatBar; then
    BIN="$(swift build -c release --show-bin-path)"
else
    echo "swift build failed; building with swiftc directly." >&2
    build_direct
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/MoatBar" "$APP/Contents/MacOS/MoatBar"
# Images go straight into Contents/Resources, where AppResources finds them.
cp Sources/MoatBar/Resources/*.png Sources/MoatBar/Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MoatBar</string>
  <key>CFBundleDisplayName</key><string>MoatBar</string>
  <key>CFBundleIdentifier</key><string>dev.openmoat.moatbar</string>
  <key>CFBundleExecutable</key><string>MoatBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Crocodile Labs and OpenMoat contributors. MIT or Apache-2.0.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP ($VERSION). Open it with: open $APP"
