# Contributing to OpenMoat Bar

Thank you for helping. OpenMoat Bar shows what [OpenMoat](https://github.com/crocodile-labs/openmoat)
does for your coding agents: a menu bar app on macOS (Swift, SwiftUI and AppKit) and a tray
app on Linux and Windows (Qt 6, C++20). [AGENTS.md](AGENTS.md) is the working contract for
people and coding agents; this file says how to build, test and send a change.

Changes to the `openmoat` command itself belong in OpenMoat; see its
[CONTRIBUTING.md](https://github.com/crocodile-labs/openmoat/blob/main/CONTRIBUTING.md).

## The one rule

OpenMoat Bar is read-only. It:

- runs only the read-only command lines in `MoatClient.allowedCommands`
  (`Sources/MoatBarCore/Moat/MoatClient.swift`, `desktop/src/core/MoatClient.cpp`), matched
  word for word: `openmoat status`, `show`, `report`, `proxy status`, `--version`, `allowed`,
  `secret list` and `doctor`, with `--format json` where OpenMoat has it, and never
  `doctor --accept`;
- never writes under `~/.moat` and never approves or allows anything;
- offers every fix as a command the person copies and runs in a terminal.

A change that breaks this needs the maintainer's explicit OK. A way around it is a security
issue: report it as [SECURITY.md](SECURITY.md) says.

## Layout

| Path | What |
| --- | --- |
| `Sources/MoatBarCore` | macOS logic without a screen: OpenMoat's JSON shapes, running `openmoat`, the snapshot, text with logic |
| `Sources/MoatBar` | the macOS app (AppKit and SwiftUI); keep logic out of it |
| `Tests/MoatBarCoreTests` | XCTest, fixtures in `Fixtures/` shared with the desktop tests |
| `desktop/` | the Linux and Windows app: `src/core` (logic), `src/app` (tray, Qt Quick views), `tests`, `tools` (screenshots) |
| `Scripts/` | `package_app.sh`, `snapshots.sh`, the installers |
| `docs/` | architecture notes and the README images |

The code still uses the old name in identifiers: the Swift targets `MoatBar` and
`MoatBarCore`, the C++ namespace `moatbar`, the CMake targets `moatbar_*`.

## macOS

Swift 5.7 or later (Xcode or the Command Line Tools), macOS 12 or later.

```
make build    # swift build
make test     # swift test
make lint     # swiftformat --lint . and swiftlint --strict, what CI runs
make format   # swiftformat . and swiftlint --fix
make app      # Scripts/package_app.sh: "OpenMoat Bar.app" in the repository root
```

`package_app.sh` builds with `swift build` and falls back to `swiftc` directly when SwiftPM
can't read `Package.swift` (some Command Line Tools installs). `MOATBAR_DIRECT_BUILD=1` forces
the `swiftc` build, as CI does once per run; `MOATBAR_UNIVERSAL=1` builds for Apple silicon and
Intel (needs Xcode). Install `swiftformat` and `swiftlint` with Homebrew.

CI (`ci.yml`, macOS 14) runs format, lint, `swift build -c release`, `swift test`, the
`swiftc` package build and `Scripts/snapshots.sh`.

## Linux and Windows

Qt 6.4 or later with Qt Quick, CMake 3.21 and a C++20 compiler. Install commands for each
system are in the [README](README.md#install-and-run).

```
cmake -S desktop -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build --build-config Release --output-on-failure
./build/src/app/openmoat-bar
```

Warnings are errors with GCC and Clang (`MOATBAR_WARNINGS_AS_ERRORS`). CI (`desktop.yml`) builds
and tests on Ubuntu and Windows with Qt 6.7, and once more with Ubuntu's own Qt 6.4 packages
exactly as the README lists them.

## Screenshots

- macOS: `./Scripts/snapshots.sh` renders `docs/images` from the app's own views and the
  made-up data in `Scripts/Snapshots`. Re-run it when a view in the README changes.
- Linux and Windows: `QT_QPA_PLATFORM=offscreen ./build/tools/moatbar_shots screenshots` draws
  the tray menu, the icons and every Quick View page from the fixtures, and fails on any QML
  warning. CI keeps the images with each run (`moatbar-linux-screenshots`,
  `moatbar-windows-screenshots`) and, for branches of this repository, pushes them to the
  `ci-shots/linux` and `ci-shots/windows` branches so they can be read without downloading.

## Keeping up with OpenMoat

Both apps decode the same fixtures, `Tests/MoatBarCoreTests/Fixtures/*.json`: the shapes of
real `openmoat … --format json` output with made-up values. When OpenMoat adds a field, a host,
a rule id or a doctor check that the app should show:

1. Add or extend a fixture from real output (replace paths, ids and secrets with made-up ones).
2. Decode it in both apps. Keep OpenMoat's field names in `CodingKeys` and name the OpenMoat
   source file the shape comes from. Unknown enum values decode to a safe default, never
   "protected" and never "allowed".
3. Add a test on each platform (`Tests/MoatBarCoreTests`, `desktop/tests`). An older OpenMoat
   that does not send the field must still decode, and nothing new shows.

Tests never call a real `openmoat` and never read or write the person's real settings.

## Commits and pull requests

- One topic per pull request. Short imperative titles, as in the history: "Show the project
  settings files openmoat status points at".
- The pull request template asks for **What**, **Testing**, **Security impact** and a
  **Release note**: what changed, what you ran and what it showed, whether the change alters
  what the app runs, reads or writes, and one line for users (or "none").
- A user-visible change adds that line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
- UI words are plain: say what happened and what it means.

## AI-assisted contributions

Built with Claude Code, Codex, Cursor or any other tool? Welcome. No disclosure or attribution
is required, and none is forbidden. The bar is the same for every change: you have read and
understood what you submit, you ran the checks above, the Testing and Security impact sections
are true, and you can answer review questions about it. `AGENTS.md` is written for coding
agents as much as for people; point your tool at it.

## Licence

Contributions are shared under the same two licences as the rest of the project: the
[MIT License](LICENSE) and the [Apache License 2.0](LICENSE-APACHE). There is no separate
agreement to sign.
