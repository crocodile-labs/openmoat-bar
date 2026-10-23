# OpenMoat Bar for Linux and Windows

The same OpenMoat Bar as on macOS, for Linux and Windows: a tray croc and a small window that show
which coding agents OpenMoat protects, what it blocked and why, and a notification when
protection drops. Read-only, like the Mac app. What differs from macOS:
[MAC_COMPARISON.md](MAC_COMPARISON.md).

Qt 6 (Qt Quick for the windows) and C++20, one codebase for both systems. It reads OpenMoat the
same way as the Mac app, through `moat … --format json`, and its tests use the Mac app's
fixtures (`Tests/MoatBarCoreTests/Fixtures`), so both apps read moat's JSON the same way.

## Layout

| Path | What |
| --- | --- |
| `src/core` | No GUI, Qt Core only: moat's JSON (`Models`, `Json`), the read-only `MoatClient`, `Snapshot` (every count the tray shows), `IconState`, `SecurityChecks`, `Text` (rule explanations, copyable commands, links) |
| `src/app` | The tray: `SnapshotStore` (reads off the GUI thread; refreshes on audit-log changes, every 60 s, on request), `TrayIcon`, `TrayMenu` (the right-click menu), `TrayController`; the Quick View: `QuickViewModel` (a snapshot as lists for QML), `QuickView` (the window), `DetailsModel` (What you allowed, Secrets and Checks, read off the GUI thread); the Activity window: `ActivityModel`, `ActivityWindow`; Welcome and Settings: `Preferences`, `SettingsWindows`; `EventViews` (a call as QML sees it); `qml/` |
| `tests` | Qt Test suites for `src/core` and `QuickViewModel` |
| `tools` | `moatbar_shots`: draws the menu, the tray icons and every Quick View page from the fixtures into PNG files, and fails on any QML warning |

## The Quick View

Clicking the tray icon opens the Quick View: the macOS menu's content in a small window, in
the same order. Agent tabs on top, then who is protected, problems, Today, Blocked / Asked /
Left to your agent / Allowed (click one for its calls, click a call for the whole story),
agents and security checks, then Refresh, docs, About and Quit. On Windows it is a flyout
beside the taskbar that closes when you click elsewhere; on Linux a normal window. A right
click on the icon still opens the plain tray menu, which also has "Open OpenMoat Bar" for desktops
where a click opens the menu (GNOME's AppIndicator). Colours follow the desktop's palette, light
or dark. Keys: Ctrl+R refresh, Ctrl+A Activity, Esc back or close, Ctrl+Q quit.

## The Activity window

Every call in today, the last 7 days or the last 30 days, filtered by agent, verdict and rule,
with one call in full beside the list. Export saves the calls the filter matches as JSON lines,
each one exactly as `openmoat show` printed it. Opened from the Quick View (Ctrl+A, "Show all in
Activity…"), and from the tray menu.

## Welcome, Settings and notifications

The first launch shows a welcome window once. Settings (Ctrl+, in the Quick View, or the tray
menu) has the few things OpenMoat Bar decides itself:

- Start at login: an XDG autostart entry (`~/.config/autostart/dev.openmoat.bar.desktop`)
  on Linux, the per-user Run key on Windows. Off until you turn it on.
- Notifications: an agent that stops being protected always notifies. Blocked calls notify
  only if you turn it on, at most one per rule every 10 minutes, naming the rule and the agent
  but never the command.

OpenMoat Bar's settings are its own (Qt's per-user settings); it never writes to OpenMoat or `~/.moat`.

## One OpenMoat Bar, with or without a tray

Only one OpenMoat Bar runs per user. Starting it again (from the app menu, the Start menu or a
terminal) hands the request to the one that is running, over a local socket only that user
can open, and exits:

| Command | Does |
| --- | --- |
| `openmoat-bar` | Opens the Quick View |
| `openmoat-bar --activity` | Opens the Activity window |
| `openmoat-bar --settings` | Opens Settings |
| `openmoat-bar --background` | Starts without opening a window (what start at login uses) |
| `openmoat-bar --quit` | Quits the OpenMoat Bar that is running |

Without a tray (GNOME without the AppIndicator extension), OpenMoat Bar still runs. Start it from the
app menu to open the Quick View as a window; notifications go to GNOME's own notification
service.

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

You need Qt 6.4 or later, CMake 3.21 and a C++20 compiler. Install commands for each
system are in the [main README](../README.md#install-and-run).

```
cmake -S desktop -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build --build-config Release --output-on-failure
./build/src/app/openmoat-bar
```

On GNOME, the tray icon needs the "AppIndicator and KStatusNotifierItem Support" extension;
without it OpenMoat Bar runs from the app menu (see above).

## Rules

The same as the Mac app (see `../AGENTS.md`):
- OpenMoat Bar runs only `openmoat status`, `show`, `report`, `proxy status` and `--version`.
- It never writes under `~/.moat`.
- Fixes are commands the person copies into a terminal.

Logic goes in `src/core` with a test.
