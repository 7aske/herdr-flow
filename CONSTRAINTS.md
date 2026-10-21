# Constraints

Last reviewed: 2026-10-21

## Floor (always enforced, no setup required)

- Every script starts with `set -euo pipefail` (or equivalent strict mode)
- No unimplemented stubs that pretend to succeed (`exit 0` after "TODO", empty `|| true` that hides real failures on critical paths)
- No skipped or deleted tests without a reason in the commit message
- No secrets in source (tokens, cookies, private keys)
- This file does not get weakened to make a change pass

## Enforced with numbers

| Dimension | Rule | Checked by | Runs at |
|-----------|------|------------|---------|
| Lint | Zero ShellCheck findings on changed `*.sh` | `shellcheck -x bin/* lib/*.sh` (scoped to changed files when possible) | every edit / task end |
| Tests | All bats tests pass | `bats tests/` | task end |
| Secrets | No secrets in source | `gitleaks detect --redact --no-banner` (when available; else manual review) | task end / CI |

## Not in scope for this project

- Test coverage % gates, accessibility, Lighthouse/performance budgets (CLI, not a web app)
- Typecheckers (bash MVP)

## Measured, not yet enforced

| Metric | Today | Direction |
|--------|-------|-----------|
| bats coverage of public CLI verbs | none yet | add a happy-path test per module before calling that module done |

## Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
|----|------|------|--------|-------|---------|
| — | — | — | — | — | — |

## Agent note

Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.
