# Architecture

MoatBar shows what OpenMoat already knows. It reads moat; it never writes to it.

## Data flow

```
openmoat status --format json        ─┐
openmoat show --since today --json   ─┼─► MoatClient ─► Snapshot ─► menu, windows, icon
openmoat proxy status --format json  ─┤        ▲
openmoat --version                   ─┘        │
                                   CommandRunner (ProcessRunner in the app, a stub in tests)
```

- `MoatClient` finds `openmoat` (`PATH`, then `/opt/homebrew/bin`, `/usr/local/bin`,
  `~/.cargo/bin`, `~/.local/bin`), or `moat` from an install before OpenMoat 0.8.0 renamed
  it, runs one read-only command with a 3 second limit, and decodes the JSON.
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
| Policy update, changed files, MCP server changes | `status` (`policy_update`, `lock_drift`, `mcp_changes`) | OpenMoat 0.5.7 and later |
| Project settings to review | `status` (`project_settings`) | OpenMoat 0.8.0 and later |
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

- Only `MoatClient.allowedCommands` are ever run, matched as whole command lines (so
  `doctor --accept`, `secret add` or a bare `proxy` can never run); a test pins the list.
- The Details screens (What you allowed, Secrets, Checks) read `openmoat allowed`,
  `openmoat secret list` and `openmoat doctor` with `--format json`, OpenMoat 0.5.5 and later. On an
  older moat each screen shows a note instead of an error, and the commands it lacks are not
  run. `openmoat doctor` exits 64 after printing its checks when one is a problem; that exit with
  output is read, not treated as a failure.
- Commands to fix things are copied to the clipboard for the person to run. That includes
  `openmoat mcp accept <server>`, which moat itself refuses outside an interactive terminal.
- Nothing leaves the machine. An update check, if added, is opt-in.
