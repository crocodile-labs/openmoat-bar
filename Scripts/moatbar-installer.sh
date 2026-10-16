#!/bin/sh
# Install or update MoatBar from its GitHub release, for the current user only.
#   macOS: ~/Applications/MoatBar.app
#   Linux: ~/.local/share/moatbar, the command ~/.local/bin/moatbar and an app menu entry
# Every download is checked against the release's SHA256SUMS before anything is installed.
# MOATBAR_VERSION=0.1.0 installs that version instead of the latest.
set -eu

REPO="crocodile-labs/moatbar"
VERSION="${MOATBAR_VERSION:-latest}"
if [ "$VERSION" = "latest" ]; then
    BASE="https://github.com/$REPO/releases/latest/download"
else
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
fi

say() { printf 'moatbar-installer: %s\n' "$*"; }
fail() { say "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# MOATBAR_DIST_DIR takes the files from a folder instead (how CI tests this script).
fetch() {
    if [ -n "${MOATBAR_DIST_DIR:-}" ]; then
        cp "$MOATBAR_DIST_DIR/$1" "$TMP/$1" || fail "no $1 in $MOATBAR_DIST_DIR"
    else
        curl --proto '=https' --tlsv1.2 -fLsS -o "$TMP/$1" "$BASE/$1" || fail "could not download $BASE/$1"
    fi
}

# Check $1 against SHA256SUMS; stop if it is missing or does not match.
verify() {
    expected="$(awk -v f="$1" '$2 == f || $2 == "*" f { print $1 }' "$TMP/SHA256SUMS")"
    [ -n "$expected" ] || fail "$1 is not in SHA256SUMS"
    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$TMP/$1" | awk '{ print $1 }')"
    else
        actual="$(shasum -a 256 "$TMP/$1" | awk '{ print $1 }')"
    fi
    [ "$expected" = "$actual" ] || fail "$1 does not match SHA256SUMS; nothing was installed"
}

fetch SHA256SUMS

case "$(uname -s)" in
Darwin)
    asset="MoatBar-macos.zip"
    fetch "$asset"
    verify "$asset"
    ditto -x -k "$TMP/$asset" "$TMP/unpacked"
    [ -d "$TMP/unpacked/MoatBar.app" ] || fail "$asset has no MoatBar.app"
    dest="$HOME/Applications/MoatBar.app"
    mkdir -p "$HOME/Applications"
    pkill -x MoatBar 2>/dev/null || true
    rm -rf "$dest"
    mv "$TMP/unpacked/MoatBar.app" "$dest"
    say "installed $dest"
    say "open it with: open ~/Applications/MoatBar.app"
    ;;
Linux)
    [ "$(uname -m)" = "x86_64" ] || fail "only x86_64 Linux has a build so far; see the README to build from source"
    asset="MoatBar-linux-x86_64.tar.gz"
    fetch "$asset"
    verify "$asset"
    mkdir -p "$TMP/unpacked"
    tar -xzf "$TMP/$asset" -C "$TMP/unpacked"
    [ -x "$TMP/unpacked/usr/bin/moatbar" ] || fail "$asset has no usr/bin/moatbar"
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    dest="$data/moatbar"
    pkill -x moatbar 2>/dev/null || true
    rm -rf "$dest"
    mkdir -p "$data" "$HOME/.local/bin" "$data/applications" "$data/icons/hicolor/256x256/apps"
    mv "$TMP/unpacked" "$dest"
    ln -sf "$dest/usr/bin/moatbar" "$HOME/.local/bin/moatbar"
    cp "$dest/usr/share/icons/hicolor/256x256/apps/dev.openmoat.moatbar.png" "$data/icons/hicolor/256x256/apps/"
    sed "s|^Exec=.*|Exec=$dest/usr/bin/moatbar|" "$dest/usr/share/applications/dev.openmoat.moatbar.desktop" \
        > "$data/applications/dev.openmoat.moatbar.desktop"
    say "installed $dest"
    say "start it from your app menu, or run: ~/.local/bin/moatbar"
    ;;
*)
    fail "this script is for macOS and Linux; on Windows use moatbar-installer.ps1"
    ;;
esac

command -v moat >/dev/null 2>&1 || say "MoatBar shows what OpenMoat does; install OpenMoat too: https://github.com/crocodile-labs/openmoat#install"
