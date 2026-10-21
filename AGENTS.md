# Working on MoatBar

MoatBar is a read-only menu bar app for OpenMoat. Read this before changing anything.

## The one rule

MoatBar never changes OpenMoat. It runs only the read-only openmoat commands listed in
`MoatClient.allowedCommands` (the `openmoat` binary, or `moat` from an install before the
rename), whole command lines word for word (`status`, `show`, `report`,
`proxy status`, `--version`, `allowed`, `secret list`, `doctor`, each with `--format json`
where moat has it; `doctor` never with `--accept`),
never writes under `~/.moat`, and never approves or allows anything. Every fix it offers is a
command the person copies and runs in Terminal. A change that breaks this needs the
maintainer's explicit OK.

## Layout

- `Sources/MoatBarCore`: everything that works without a screen.
  - `Moat/`: moat's JSON shapes (`Protection`, `Event`, `Action`, `Summary`, `ProxyState`),
    `MoatClient` (finds and runs moat), `CommandRunner` (the process seam tests replace).
  - `State/`: `Snapshot` (one read of moat and every count the UI shows), `IconState`.
  - `Text/`: words the UI shows that need logic (rule explanations, copyable commands).
- `Sources/MoatBar`: the AppKit app. Keep logic out of it; put it in Core with a test.
- `Tests/MoatBarCoreTests`: XCTest, one `FeatureTests` file per Core area, fixtures in
  `Fixtures/` copied from real moat output shapes with made-up values.
- `docs/`: architecture and design notes.

## Build, test, lint

```
make build    # swift build
make test     # swift test
make lint     # swiftformat --lint, swiftlint --strict (what CI runs)
make format   # fix formatting
```

## Coding style

- SwiftFormat and SwiftLint are enforced in CI. 4-space indent, 120 columns.
- Refer to members as `self.x`. Small typed structs and enums; `// MARK: -` sections.
- Keep moat's JSON field names in `CodingKeys` and point to the openmoat source file the
  shape comes from. Decode unknown enum values to a safe default (never "protected",
  never "allowed").
- Swift 5.7 syntax, macOS 12 APIs. Newer APIs go behind `if #available`.
- Tests: `test_subject_expectation` names; build fixtures, never call a real moat.
- UI words are plain: say what happened and what it means. No jargon in the menu.

## Commits and PRs

- Short imperative commit titles ("Add the agent tab"). One topic per PR.
- PR body: what changed, how it was tested, and a Security impact line.
- No AI attribution lines in commits or PRs.
