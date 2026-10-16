# Architecture

MoatBar shows what OpenMoat already knows. It reads moat; it never writes to it.

## Data flow

```
moat status --format json        ─┐
moat show --since today --json   ─┼─► MoatClient ─► Snapshot ─► menu, windows, icon
moat proxy status --format json  ─┤        ▲
moat --version                   ─┘        │
                                   CommandRunner (ProcessRunner in the app, a stub in tests)
```

- `MoatClient` finds the moat binary (`PATH`, then `/opt/homebrew/bin`, `/usr/local/bin`,
  `~/.cargo/bin`), runs one read-only command with a 3 second limit, and decodes the JSON.
- `Snapshot` is one read: protection per agent, today's events, the proxy state. Every
  number on screen is computed from it (counts per verdict, per agent, per hour, sessions,
  top rules), so the UI holds no logic of its own.
- `IconState` turns a snapshot into the menu bar icon: red (an agent lost protection),
  amber (a check needs a look), a dot (new blocks), plain, or grey (moat missing).

## Where the data comes from

| Screen | moat command | Available |
| --- | --- | --- |
| Menu counts, Today bar, lists, one decision | `show --since today` | yes |
| Agents, red state | `status` | yes |
| Proxy line | `proxy status` (macOS, Linux) | yes |
| Activity window, 7 / 30 days | `report --since 7d` | yes |
| Security checks | `doctor` as JSON | needs moat CLI work |
| What you allowed, trusted repos | allows / grants / trust lists as JSON | needs moat CLI work |
| Secrets | secret names and hosts as JSON, never values | needs moat CLI work |

## Refresh

- When the audit log changes (file watch on `~/.moat/audit.db`): re-read events, at most
  every 2 seconds.
- Every 60 seconds: re-read status, so a removed hook turns the icon red.
- When the menu opens: re-read everything.
- A read that fails keeps the last good snapshot on screen with its time.

## Safety

- Only `MoatClient.allowedCommands` are ever run; a test pins the list.
- Commands to fix things are copied to the clipboard for the person to run.
- Nothing leaves the machine. An update check, if added, is opt-in.
