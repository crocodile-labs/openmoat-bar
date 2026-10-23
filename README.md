<p align="center">
  <img src="docs/images/app-icon.png" width="128" alt="MoatBar">
</p>

<h1 align="center">MoatBar</h1>

<p align="center">
  See what <a href="https://github.com/crocodile-labs/openmoat">OpenMoat</a> does for your coding agents, from the menu bar.
</p>

MoatBar shows which of your agents (Claude Code, Codex, Cursor, OpenClaw, GitHub Copilot CLI, pi, Gemini CLI) are protected, what OpenMoat
blocked today and why, and tells you when protection drops.

It is read-only. MoatBar never allows anything or changes a rule; every fix is a command you
copy into Terminal.

| Platform | Status |
| --- | --- |
| macOS 12 or later | In development: menu bar app, Activity window, Settings |
| Linux, Windows | In development ([`desktop/`](desktop)): the macOS features in a Qt Quick app. Clicking the tray croc opens the Quick View (the menu's content in a small window); also the Activity window, Welcome, Settings and notifications, and it runs without a tray. Built, tested and drawn in CI on Ubuntu and Windows, not yet tried on a real desktop. [How it compares with macOS](desktop/MAC_COMPARISON.md) |

![The MoatBar menu: Blocked, then the list of blocked calls, then one decision in full](docs/images/menu.png)

## What it shows

**The menu**
- Agent tabs with each agent's icon. The line under a tab is its protection.
- Today's calls per hour, with blocks in red.
- Blocked, Asked, Left to your agent and Allowed, with counts.
  - Hover one for the list.
  - Hover a call for the whole story: what ran, the rule, what the agent was told, and why. You can copy a `openmoat policy check` command or report a wrong block.
- Each agent with its protection level, today's numbers and last call. Security checks cover each agent, the network proxy and moat itself.

<p align="center">
  <img src="docs/images/agent-tab.png" width="390" alt="One agent's tab">
</p>

**The croc in the menu bar** changes with what needs you:

| Icon | What it means |
| --- | --- |
| Plain | All protected, nothing new |
| Dot | New blocks since you last looked |
| Amber | A security check needs a look |
| Red | An agent stopped being protected |
| Faded | OpenMoat isn't installed or can't be read |

**Notices in the menu** (OpenMoat 0.5.7 and later):
- "Policy update available" when a newer default policy has changes, with `openmoat policy upgrade` to copy. It shows each change and asks first.
- "OpenMoat's files changed" when a file OpenMoat pinned was changed or removed, with the list and `openmoat doctor`.
- "MCP server changes wait for you" when an MCP server's definition or tools changed since you accepted them. OpenMoat refuses that server's tool calls until then; MoatBar lists the changes and gives `openmoat mcp accept <server>` to copy for each server.
- "Project settings need a look" (OpenMoat 0.8.0 and later) when a project settings file could switch OpenMoat off or run a program, such as a `.claude/settings.json` with `hooks` or `env`. An agent loads it when a session starts, before any hook runs, so OpenMoat can only point at it; MoatBar lists each file with what it sets.

**Rules explained.** A call's details say in one line why its rule exists: every rule group in OpenMoat's default policy (as of 0.9.0), the rules OpenMoat's guard, `openmoat run` and its network proxy add themselves (a tainted session, a changed project settings file, a program that isn't the pinned one, a refused connection, ...), the policy's default for a kind of call, and rules from a policy pack or a repository's own policy. A call decided while a pinned settings file had drifted in a harmless way gets a note saying so.

**The Details window** (from the menu, OpenMoat 0.5.5 and later):
- What you allowed: permanent rules, session grants with when they end, and trusted repositories, each with the command that takes it back.
- Secrets: each brokered secret's id, host and where its value is read from, and whether the agent can still read it there.
- Checks: every `openmoat doctor` check, grouped into problems, things to look at, notes and fine, with checks about the same thing (policy, hooks, MCP servers, audit log, ...) kept together and labelled. Newer checks get a line on what they mean: whether a repository policy is signed by a key you trust, a changed policy pack, the last audit anchor, a Claude Code hook that lets calls run when it fails, and MCP servers to accept, with the command to copy.

With an older moat these show a short note saying which version they need. Lines and fields an older moat doesn't print simply don't show.

**The Activity window** (⌘A) shows today, 7 days or 30 days:
- Filter by agent, verdict and rule.
- See one call in full.
- Export the rows as JSON lines.

![The Activity window](docs/images/activity.png)

**Notifications** stay quiet:
- MoatBar always tells you when an agent stops being protected.
- Blocked calls notify only if you turn it on in Settings. Those notifications name the rule and the agent, never the command.
- Calls your agent already asks you about never notify.

**First launch** shows one welcome window, then the menu:

<p align="center">
  <img src="docs/images/welcome.png" width="460" alt="Welcome window">
</p>

## Install and run

You need OpenMoat installed first ([how](https://github.com/crocodile-labs/openmoat#install)).

### One command

There is no release yet. From the first release on, one command installs or updates MoatBar
for your user, like OpenMoat's installer:

```bash
# macOS and Linux
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/crocodile-labs/moatbar/releases/latest/download/moatbar-installer.sh | sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -c "irm https://github.com/crocodile-labs/moatbar/releases/latest/download/moatbar-installer.ps1 | iex"
```

The installer checks the download against the release's `SHA256SUMS`, then puts MoatBar in:

| System | Where | Remove it |
| --- | --- | --- |
| macOS (Apple silicon and Intel) | `~/Applications/MoatBar.app` | `rm -rf ~/Applications/MoatBar.app` |
| Linux x86_64 | `~/.local/share/moatbar`, the `moatbar` command in `~/.local/bin`, an app menu entry | `rm -rf ~/.local/share/moatbar ~/.local/bin/moatbar ~/.local/share/applications/dev.openmoat.moatbar.desktop` |
| Windows x64 | `%LOCALAPPDATA%\Programs\MoatBar` and a Start menu entry | Delete that folder and the MoatBar Start menu entry |

Until then, or to build it yourself:

### macOS

```bash
brew install crocodile-labs/tap/openmoat
git clone https://github.com/crocodile-labs/moatbar
cd moatbar
make app            # needs Swift 5.7 or later (Xcode or the Command Line Tools)
open MoatBar.app
```

`make app` falls back to building with `swiftc` directly when `swift build` can't read
`Package.swift`; this happens on some Command Line Tools installs.

### Linux

```bash
brew install crocodile-labs/tap/openmoat

# Build tools and Qt 6.4 or later with Qt Quick, for your distribution
# Ubuntu 24.04+, Debian 12+:
sudo apt install build-essential cmake git qt6-base-dev qt6-declarative-dev \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-templates qml6-module-qtquick-window qml6-module-qtqml-workerscript
# Fedora:
sudo dnf install gcc-c++ cmake git qt6-qtbase-devel qt6-qtdeclarative-devel
# Arch:
sudo pacman -S --needed base-devel cmake git qt6-base qt6-declarative

git clone https://github.com/crocodile-labs/moatbar
cd moatbar
cmake -S desktop -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/src/app/moatbar
```

CI runs the Ubuntu line exactly as written; the Fedora and Arch lines are not tested yet. On
GNOME without Ubuntu's tray support (Fedora, for example), the tray icon needs the "AppIndicator
and KStatusNotifierItem Support" extension. Without it MoatBar still runs: open it from the app
menu and it shows as a window.

### Windows

In PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://github.com/crocodile-labs/openmoat/releases/latest/download/openmoat-installer.ps1 | iex"

# Build tools: Git, CMake, Python (for the Qt installer) and the Visual C++ compiler
winget install --id Git.Git
winget install --id Kitware.CMake
winget install --id Python.Python.3.12
winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --wait"
```

Open a new PowerShell window so the tools are on `PATH`, then:

```powershell
# Qt 6.7.3, without a Qt account
python -m pip install aqtinstall
python -m aqt install-qt windows desktop 6.7.3 win64_msvc2019_64 --outputdir C:\Qt

git clone https://github.com/crocodile-labs/moatbar
cd moatbar
cmake -S desktop -B build -DCMAKE_PREFIX_PATH=C:\Qt\6.7.3\msvc2019_64
cmake --build build --config Release
cmake --install build --config Release --prefix MoatBar
C:\Qt\6.7.3\msvc2019_64\bin\windeployqt.exe MoatBar\bin\moatbar.exe
.\MoatBar\bin\moatbar.exe
```

`windeployqt` copies Qt's DLLs next to `moatbar.exe`, so it starts from Explorer too. The
release workflow builds the same way, but the winget and aqtinstall steps are not tested.

### See the Linux and Windows menus without the machine

Every CI run draws the Linux and Windows menus offscreen and keeps the images with the run:
open the run under Actions, then download `moatbar-linux-screenshots` or
`moatbar-windows-screenshots`. More in [desktop/README.md](desktop/README.md).

## How it works

MoatBar runs only these read-only moat commands and reads their JSON:
- `openmoat status`
- `openmoat show`
- `openmoat report`
- `openmoat proxy status`
- `openmoat --version`
- `openmoat allowed`, `openmoat secret list` and `openmoat doctor`, for the Details screens

Each with `--format json`. MoatBar matches whole command lines, so `openmoat doctor --accept` or `openmoat secret add` can never run.

OpenMoat 0.8.0 renamed the command from `moat` to `openmoat`. MoatBar looks for `openmoat` first and falls back to `moat` from an older install. The commands it offers to copy say `openmoat`; an older install does not have that name until you update it.

It re-reads when OpenMoat's audit log changes (within 2 seconds), every minute, and when you open the menu. It writes nothing to `~/.moat`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Develop

```
make build   make test   make lint   make format
./Scripts/snapshots.sh   # re-render the screenshots above from the app's views
```

Read [AGENTS.md](AGENTS.md) first. The screenshots are rendered from the app's own views with made-up data.

## License

MIT or Apache-2.0, at your option. The agent icons come from [CodexBar](https://github.com/steipete/CodexBar) (MIT); see `Sources/MoatBar/Resources/ICONS.md`.
