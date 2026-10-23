# Changelog

All notable changes to OpenMoat Bar (formerly MoatBar) are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). Entries are one line each, linked to their pull
request where there is one; each version links to its compare view at the end of the file.

## [Unreleased]

## [0.3.0] - Unreleased

**Upgrading:** run the installer again. It replaces a MoatBar install, and the app copies
MoatBar's settings on its first start. On macOS, turn "Open at login" on again in Settings if
you used it: macOS ties that switch to the old app.

### Changed
- MoatBar is now OpenMoat Bar, in the repository `crocodile-labs/openmoat-bar`. The macOS app is `OpenMoat Bar.app` (bundle id `dev.openmoat.bar`), the Linux and Windows command is `openmoat-bar`, the installers are `openmoat-bar-installer.sh` and `openmoat-bar-installer.ps1`, and the release files start with `openmoat-bar-`.
- Settings carry over from MoatBar once on the first start (macOS defaults, Qt settings on Linux and Windows). A MoatBar start-at-login entry on Linux and Windows is replaced by OpenMoat Bar's, a MoatBar still running is asked to quit, and the installers remove the old install, so the app does not run twice.
- The app looks for `openmoat` first and falls back to `moat` from an install before OpenMoat 0.8.0; every command it offers to copy says `openmoat` ([#28](https://github.com/crocodile-labs/openmoat-bar/pull/28)).
- The MIT licence text is now `LICENSE` (it was `LICENSE-MIT`), beside `LICENSE-APACHE`; the project is still `MIT OR Apache-2.0`.

### Added
- Details window with three read-only screens: what you allowed, secrets, and every `openmoat doctor` check; the main view shows a policy update and changed pinned files ([#26](https://github.com/crocodile-labs/openmoat-bar/pull/26)).
- MCP server changes waiting for `openmoat mcp accept`, the newer doctor checks grouped by topic, and explanations for the rules OpenMoat 0.5.7 added, on macOS, Linux and Windows ([#27](https://github.com/crocodile-labs/openmoat-bar/pull/27)).
- The project settings files `openmoat status` points at (OpenMoat 0.8.0 and later), in a card with `openmoat doctor` to copy and in Security checks ([#29](https://github.com/crocodile-labs/openmoat-bar/pull/29)).
- Every host OpenMoat reports is named, including OpenClaw, GitHub Copilot CLI, pi and Gemini CLI with their icons, and events from OpenMoat's network proxy, MCP proxy and `openmoat run` ([#30](https://github.com/crocodile-labs/openmoat-bar/pull/30)).
- One line explaining every rule in OpenMoat 0.9.0's default policy, the rules the guard, `openmoat run` and the network proxy add, and `default.<kind>` ([#30](https://github.com/crocodile-labs/openmoat-bar/pull/30)).
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` and this changelog.

## [0.2.0] - 2026-10-17

### Added
- Linux and Windows: the Quick View, the macOS menu's content in a Qt Quick window opened from the tray croc ([#16](https://github.com/crocodile-labs/openmoat-bar/pull/16)).
- Linux and Windows: the Activity window ([#17](https://github.com/crocodile-labs/openmoat-bar/pull/17)).
- Linux and Windows: the welcome window, Settings with start at login, and opt-in block notifications ([#18](https://github.com/crocodile-labs/openmoat-bar/pull/18)).
- Linux and Windows: one instance per user, `--activity`, `--settings`, `--background` and `--quit` for the running one, and a mode without a tray ([#19](https://github.com/crocodile-labs/openmoat-bar/pull/19)).
- `desktop/MAC_COMPARISON.md`: what each platform does and does not have ([#20](https://github.com/crocodile-labs/openmoat-bar/pull/20)).

## [0.1.0] - 2026-10-16

### Added
- The macOS menu bar app: agent tabs, today's calls per hour, Blocked, Asked, Left to your agent and Allowed with each call in full, and a menu bar icon that changes with what needs you ([#1](https://github.com/crocodile-labs/openmoat-bar/pull/1), [#2](https://github.com/crocodile-labs/openmoat-bar/pull/2), [#8](https://github.com/crocodile-labs/openmoat-bar/pull/8), [#10](https://github.com/crocodile-labs/openmoat-bar/pull/10), [#12](https://github.com/crocodile-labs/openmoat-bar/pull/12)).
- Refresh when OpenMoat's audit log changes, and a notification when an agent stops being protected ([#3](https://github.com/crocodile-labs/openmoat-bar/pull/3)).
- The welcome window, Settings and opt-in block notifications ([#4](https://github.com/crocodile-labs/openmoat-bar/pull/4)).
- The Activity window: today, 7 or 30 days, filters, one call in full, export as JSON lines ([#5](https://github.com/crocodile-labs/openmoat-bar/pull/5)).
- Security checks from `moat status` and `moat proxy status` ([#6](https://github.com/crocodile-labs/openmoat-bar/pull/6)).
- A build with `swiftc` when SwiftPM can't read the manifest ([#7](https://github.com/crocodile-labs/openmoat-bar/pull/7)).
- The app icon and an About panel ([#9](https://github.com/crocodile-labs/openmoat-bar/pull/9)).
- The first Linux and Windows build (Qt 6, C++20), with screenshots drawn in CI ([#11](https://github.com/crocodile-labs/openmoat-bar/pull/11), [#13](https://github.com/crocodile-labs/openmoat-bar/pull/13)).
- The release workflow and one-command installers for macOS, Linux and Windows ([#14](https://github.com/crocodile-labs/openmoat-bar/pull/14), [#15](https://github.com/crocodile-labs/openmoat-bar/pull/15)).

[Unreleased]: https://github.com/crocodile-labs/openmoat-bar/compare/v0.2.0...HEAD
[0.3.0]: https://github.com/crocodile-labs/openmoat-bar/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/crocodile-labs/openmoat-bar/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/crocodile-labs/openmoat-bar/releases/tag/v0.1.0
