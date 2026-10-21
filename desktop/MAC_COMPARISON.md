# Linux and Windows compared with macOS

What the Linux and Windows app (`desktop/`) does compared with the macOS app (`Sources/`), as of
this checkout. Both read the same `moat … --format json`, and their tests share one set of
fixtures (`Tests/MoatBarCoreTests/Fixtures`).

| Area | macOS | Linux and Windows |
| --- | --- | --- |
| Where it lives | Menu bar croc; the menu opens on click | Tray croc. A click opens the Quick View: the menu's content in a small window (a flyout by the taskbar on Windows, a normal window on Linux). A right click opens a plain tray menu |
| Icon states | Plain, dot, amber, red, faded | The same |
| Agent tabs, Today chart | Yes | Yes |
| Blocked / Asked / Left to your agent / Allowed | Hover for the list, hover a call for the whole story | Click for the list, click a call for the whole story |
| Copy a command | "Copied ✓", menu stays open | "Copied ✓" |
| Agents, sessions, security checks | Yes | Yes |
| Refresh | Row with a spinner, menu stays open | The same, in the Quick View |
| What you allowed, Secrets, Checks | The Details window, from the menu; one tab each | Three Quick View pages, from the overview or the tray menu |
| Policy update, changed files, MCP server changes | A card in the menu with the command to copy (`openmoat mcp accept <server>` per server); also in Security checks | The same, in the Quick View and the tray menu |
| Checks page | Grouped by status, checks about the same thing kept together with a topic label; one-line explanations for the newer checks; the accept command on MCP lines | The same |
| Rule explanations | One line per rule in a call's details, the same table on both (`RuleText.swift`, `Text.cpp`); a note for settings drift | The same, in the Quick View and the tray menu |
| Older moat | A note per screen: needs OpenMoat 0.5.5 (0.5.7 for the update notices) | The same |
| Activity window | Today / 7 days / 30 days, filters, one call in full, export | The same. The export keeps each event exactly as `openmoat show` printed it |
| Welcome window | Once, on the first launch | The same |
| Settings | Open at login (macOS 13 and later), block notifications, where moat is | Start at login (XDG autostart on Linux, the per-user Run key on Windows), block notifications, where moat is |
| Notifications | Lost protection always; blocks opt-in, one per rule per 10 minutes, never the command | The same. Without a tray they go to the freedesktop service on D-Bus |
| Without a tray | n/a | GNOME without the AppIndicator extension: open MoatBar from the app menu and it shows as a window |
| One instance, command line | n/a | One per user. `moatbar`, `--activity`, `--settings`, `--background`, `--quit` hand the request to the running one |
| Light and dark | Follows macOS | Follows the desktop's palette |
| Install | `make app` | CMake from source, or the release installer |
| Shown in CI | Screenshots rendered from the app's views | Every window drawn offscreen on Linux (Qt 6.7 and Ubuntu's Qt 6.4) and Windows; images on the `ci-shots/*` branches; any QML warning fails the build |

## Not tried yet

The Linux and Windows app has been built, tested and drawn in CI only. Nobody has run it on a
real KDE, GNOME or Windows desktop yet, so tray behaviour (click versus right click, where the
flyout sits, notifications) is unconfirmed there. The Fedora and Arch package lines in the README
are untested.
