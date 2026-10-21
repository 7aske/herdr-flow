# Capability Map: herdr-flow

Approved 2026-10-21 (from confirmed intent in `docs/intent/herdr-flow.md`).

| Module id | Responsibility | Depends on |
|-----------|----------------|------------|
| `tw-bridge` | Read/update TW tasks; UDAs/annotations for repo, phase, artifact path, session link; create next-phase and open-PR tasks | — |
| `artifacts` | One MD per phase under a stable shared root; path helpers + open shortcut (`$EDITOR`/`nvim`) | — |
| `herdr-git` | Ensure Herder workspace for repo; create/reuse worktree labelled `<action>:<id>-kebab` with git branch `<action>/<id>-kebab` | `tw-bridge` |
| `phases` | Manual phase entry (spec → plan → build → review): prompt + lifecycle skill hint, start or resume agent session, write the single artifact, update TW | `tw-bridge`, `artifacts`, `herdr-git` |
| `ship-pr` | After review: TW task whose command runs `gh` or `glab` to open the PR | `tw-bridge`, `herdr-git` |

**Build order:** `tw-bridge`, `artifacts` → `herdr-git` → `phases` → `ship-pr`

Module specs (working drafts): `~/.scratch/tasks/herdr-flow/SPEC-<module-id>.md`  
Promote to `docs/specs/` after approval.
