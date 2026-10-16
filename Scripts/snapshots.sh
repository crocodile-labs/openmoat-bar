#!/bin/bash
# Render the README screenshots into docs/images from the app's own views and
# made-up data (Scripts/Snapshots). Built with swiftc so it works without SwiftPM.
set -euo pipefail

cd "$(dirname "$0")/.."
out=".build/snapshots"
target="$(uname -m)-apple-macos12"
mkdir -p "$out/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$PWD/$out/ModuleCache"
flags=(-target "$target" -module-cache-path "$PWD/$out/ModuleCache")

swiftc "${flags[@]}" -parse-as-library -emit-library -static -emit-module \
    -module-name MoatBarCore -emit-module-path "$out/MoatBarCore.swiftmodule" \
    $(find Sources/MoatBarCore -name '*.swift') -o "$out/libMoatBarCore.a"
# The app's sources without its main.swift, plus the snapshot program.
swiftc "${flags[@]}" -I "$out" -L "$out" -lMoatBarCore -module-name Snapshots \
    $(find Sources/MoatBar -name '*.swift' ! -name main.swift) Scripts/Snapshots/*.swift \
    -o "$out/snapshots"
# Images are looked up next to the binary.
cp Sources/MoatBar/Resources/*.png Sources/MoatBar/Resources/AppIcon.icns "$out/"
"$out/snapshots" docs/images
