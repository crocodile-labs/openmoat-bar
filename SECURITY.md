# Security policy

OpenMoat Bar is a read-only viewer for [OpenMoat](https://github.com/crocodile-labs/openmoat).
It runs a fixed list of read-only `openmoat … --format json` command lines, shows what they
print, and offers fixes as commands to copy. It never writes under `~/.moat`, never approves or
allows a call, and never runs a command it offers to copy. Anything that breaks that is a vulnerability.

## Supported versions

| Version | Security fixes |
| --- | --- |
| the latest release | yes, in its next release |
| older releases | no; upgrade to the latest |
| `main` | yes, fixes land here first |

## Reporting

Use GitHub's private advisory form for this repository:
[report a vulnerability](https://github.com/crocodile-labs/openmoat-bar/security/advisories/new).
Only the maintainers see it. A problem in OpenMoat itself (a policy bypass, the guard, the
proxy) goes to [OpenMoat's security policy](https://github.com/crocodile-labs/openmoat/blob/main/SECURITY.md)
instead; if you are not sure which, report it here and we will move it.

Do not open public issues or pull requests for vulnerabilities. A useful report has the app
version (About), the `openmoat --version`, the operating system, and the steps that show the
problem.

## What happens next

| Step | Target |
| --- | --- |
| Acknowledgement | 72 hours |
| Triage: confirmed or not, severity | 7 days |
| Fix for a confirmed critical or high issue | 30 days |
| Public disclosure | when the fix ships, and at most 90 days after the report unless we agree otherwise |

Confirmed issues in a released version get a GitHub Security Advisory, and you are credited
unless you prefer otherwise.

## What counts as a vulnerability

| In scope | Example |
| --- | --- |
| Writing state | the app writes under `~/.moat`, changes an agent's hook or settings file, or edits the policy |
| Approving or allowing | anything in the app that approves a call, grants a session, trusts a repository or accepts an MCP server |
| Running commands | a command line outside the read-only list runs, `openmoat doctor --accept` runs, or a command shown to copy runs by itself |
| Leaking | secret values, or the text of commands and paths, shown where the app promises not to (notifications name the rule and the agent only) or written anywhere outside the person's own export |
| Installers and releases | an installer that skips the `SHA256SUMS` check or installs outside the current user's folders |

## Out of scope

- What OpenMoat decides: the app only shows it. Report decisions to OpenMoat.
- An attacker who already runs code as the same user: they can read the same data directly.
- The app showing old data until its next refresh.

## Safe harbour

Research on your own machine, against your own copy of the app and OpenMoat, is welcome and
will not be pursued. Do not test against systems or data that are not yours.
