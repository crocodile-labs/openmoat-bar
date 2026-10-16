# MoatBar

See what [OpenMoat](https://github.com/crocodile-labs/openmoat) does for your coding agents, from the menu bar.

MoatBar is read-only. It shows which agents are protected, what was blocked today and why,
and tells you when protection drops. It never allows anything or changes a rule: every fix
is a command you copy into Terminal.

Status: in development. macOS 12 or later; Linux and Windows follow.

## What it shows

- **The menu bar croc:** red when an agent lost protection, amber when a check needs a look,
  a dot for new blocks, faded when moat is missing.
- **The menu:**
  - Agent tabs, today's calls per hour, and Blocked / Asked / Left to your agent / Allowed.
  - Each list opens one decision: what ran, the rule, what the agent was told, and why.
  - Each agent shows its protection, today's numbers and its sessions.
- **Notifications:**
  - Always sent when an agent stops being protected.
  - Blocked calls notify only if you turn it on.

## Build and run

You need OpenMoat installed (`brew install crocodile-labs/tap/moat`) and Swift 5.7 or later.

```
make app              # builds MoatBar.app
open MoatBar.app
```

`swift run MoatBar` also works for a quick look; notifications and open-at-login need the app bundle.

## Develop

```
make build   make test   make lint   make format
```

Read [AGENTS.md](AGENTS.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first.

## License

MIT or Apache-2.0, at your option.
