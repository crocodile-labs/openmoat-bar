#!/bin/sh
# Install or update OpenMoat Bar from its GitHub release, for the current user only.
#   macOS: ~/Applications/OpenMoat Bar.app
#   Linux: ~/.local/share/openmoat-bar, the command ~/.local/bin/openmoat-bar and an app menu entry
# Every download is checked against the release's SHA256SUMS before anything is installed.
# OPENMOAT_BAR_VERSION=0.3.0 installs that version instead of the latest.
# An install from before the rename (MoatBar) is replaced, and its start at login carried over.
set -eu

REPO="crocodile-labs/openmoat-bar"
VERSION="${OPENMOAT_BAR_VERSION:-${MOATBAR_VERSION:-latest}}"
if [ "$VERSION" = "latest" ]; then
    BASE="https://github.com/$REPO/releases/latest/download"
else
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
fi

say() { printf 'openmoat-bar-installer: %s\n' "$*"; }
fail() { say "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# OPENMOAT_BAR_DIST_DIR takes the files from a folder instead (how CI tests this script).
DIST_DIR="${OPENMOAT_BAR_DIST_DIR:-${MOATBAR_DIST_DIR:-}}"
fetch() {
    if [ -n "$DIST_DIR" ]; then
        cp "$DIST_DIR/$1" "$TMP/$1" || fail "no $1 in $DIST_DIR"
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
    asset="openmoat-bar-macos.zip"
    fetch "$asset"
    verify "$asset"
    ditto -x -k "$TMP/$asset" "$TMP/unpacked"
    [ -d "$TMP/unpacked/OpenMoat Bar.app" ] || fail "$asset has no OpenMoat Bar.app"
    dest="$HOME/Applications/OpenMoat Bar.app"
    mkdir -p "$HOME/Applications"
    pkill -x openmoat-bar 2>/dev/null || true
    # The same app under its old name.
    pkill -x MoatBar 2>/dev/null || true
    rm -rf "$HOME/Applications/MoatBar.app"
    rm -rf "$dest"
    mv "$TMP/unpacked/OpenMoat Bar.app" "$dest"
    say "installed $dest"
    say "open it with: open ~/Applications/OpenMoat\\ Bar.app"
    ;;
Linux)
    [ "$(uname -m)" = "x86_64" ] || fail "only x86_64 Linux has a build so far; see the README to build from source"
    asset="openmoat-bar-linux-x86_64.tar.gz"
    fetch "$asset"
    verify "$asset"
    mkdir -p "$TMP/unpacked"
    tar -xzf "$TMP/$asset" -C "$TMP/unpacked"
    [ -x "$TMP/unpacked/usr/bin/openmoat-bar" ] || fail "$asset has no usr/bin/openmoat-bar"
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    dest="$data/openmoat-bar"
    pkill -x openmoat-bar 2>/dev/null || true
    rm -rf "$dest"
    mkdir -p "$data" "$HOME/.local/bin" "$data/applications" "$data/icons/hicolor/256x256/apps"
    mv "$TMP/unpacked" "$dest"
    ln -sf "$dest/usr/bin/openmoat-bar" "$HOME/.local/bin/openmoat-bar"
    cp "$dest/usr/share/icons/hicolor/256x256/apps/dev.openmoat.bar.png" "$data/icons/hicolor/256x256/apps/"
    sed "s|^Exec=.*|Exec=$dest/usr/bin/openmoat-bar|" "$dest/usr/share/applications/dev.openmoat.bar.desktop" \
        > "$data/applications/dev.openmoat.bar.desktop"

    # The same app under its old name, MoatBar: stop it, remove it, and move its
    # start-at-login entry to the new name so it does not start twice.
    pkill -x moatbar 2>/dev/null || true
    rm -rf "$data/moatbar" "$data/applications/dev.openmoat.moatbar.desktop" \
        "$data/icons/hicolor/256x256/apps/dev.openmoat.moatbar.png"
    if [ -L "$HOME/.local/bin/moatbar" ]; then rm -f "$HOME/.local/bin/moatbar"; fi
    autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    if [ -f "$autostart/dev.openmoat.moatbar.desktop" ]; then
        sed -e "s|^Exec=.*|Exec=\"$dest/usr/bin/openmoat-bar\" --background|" \
            -e "s|^Name=.*|Name=OpenMoat Bar|" -e "s|^Icon=.*|Icon=dev.openmoat.bar|" \
            "$autostart/dev.openmoat.moatbar.desktop" > "$autostart/dev.openmoat.bar.desktop"
        rm -f "$autostart/dev.openmoat.moatbar.desktop"
        say "start at login moved from MoatBar to OpenMoat Bar"
    fi

    say "installed $dest"
    say "start it from your app menu, or run: ~/.local/bin/openmoat-bar"
    ;;
*)
    fail "this script is for macOS and Linux; on Windows use openmoat-bar-installer.ps1"
    ;;
esac

if ! command -v openmoat >/dev/null 2>&1 && ! command -v moat >/dev/null 2>&1; then
    say "OpenMoat Bar shows what OpenMoat does; install OpenMoat too: https://openmoat.dev/docs/quickstart/"
fi
