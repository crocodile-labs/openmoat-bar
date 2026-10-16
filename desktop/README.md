# MoatBar for Linux and Windows

The same MoatBar as on macOS, for Linux and Windows: a tray icon and menu that show which
coding agents OpenMoat protects, what it blocked today and why, and a notification when
protection drops. Read-only, like the Mac app.

Qt 6 and C++20, one codebase for both systems. It reads OpenMoat the same way as the Mac
app, through `moat … --format json`, and its tests use the Mac app's fixtures
(`Tests/MoatBarCoreTests/Fixtures`), so both apps read moat's JSON the same way.

## Layout

| Path | What |
| --- | --- |
| `src/core` | No GUI, Qt Core only: moat's JSON (`Models`, `Json`), the read-only `MoatClient`, `Snapshot` (every count the tray shows), `IconState`, `SecurityChecks`, `Text` (rule explanations, copyable commands, links) |
| `src/app` | The tray: `SnapshotStore` (reads off the GUI thread; refreshes on audit-log changes, every 60 s, on request), `TrayIcon`, `TrayMenu`, `TrayController` |
| `tests` | Qt Test suites for `src/core` |
| `tools` | `moatbar_shots`: draws the menu and tray icons from the fixtures into PNG files |

## Status

Builds and passes its tests on Ubuntu 24.04 and Windows Server 2022 in CI. It has not been
tried on a real Linux or Windows desktop yet.

To see the menu without either machine: every CI run draws it offscreen and keeps the images
with the run. Open the run under Actions and download `moatbar-linux-screenshots` or
`moatbar-windows-screenshots`. To draw them yourself:

```
QT_QPA_PLATFORM=offscreen ./build/tools/moatbar_shots screenshots
```

## Build

You need Qt 6.5 or later, CMake 3.21 and a C++20 compiler.

```
cmake -S desktop -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build --build-config Release --output-on-failure
./build/src/app/moatbar
```

On GNOME, the tray needs the "AppIndicator and KStatusNotifierItem Support" extension.

## Rules

The same as the Mac app (see `../AGENTS.md`):
- MoatBar runs only `moat status`, `show`, `report`, `proxy status` and `--version`.
- It never writes under `~/.moat`.
- Fixes are commands the person copies into a terminal.

Logic goes in `src/core` with a test.
