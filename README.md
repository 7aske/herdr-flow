# herdr-flow

Bash MVP: Taskwarrior → Herder workspace/worktree → manual phases (spec → plan → build → review) → `gh`/`glab` PR.

Replaces `~/.local/src/sh/dotfiles/src/tw-agent.sh` for this path (hard cutover when you are ready).

## Setup

1. UDAs in `~/.config/taskrc` (already documented in `docs/udas.md`): `phase`, `artifact`, `session`, `shipcmd` (+ existing `repo`, `branch`, `type`).
2. Put `bin/herdr-flow` on your `PATH`, or call it by absolute path.
3. Ensure `herdr`, `task`, `jq`, `git`, and `gh`/`glab` are available.

## Usage

```bash
# Task needs UDA repo=/absolute/path/to/git/repo
herdr-flow start <tw-id> --phase spec
herdr-flow resume <tw-id>
herdr-flow open-artifact <tw-id>
herdr-flow phase-done <tw-id>    # agent-callable
herdr-flow next-task <tw-id>     # creates next phase TW task (no auto-run)
herdr-flow ship-pr <tw-id> [--create-only] [--no-draft] [--no-push]
```

Artifacts: `$HOME/.local/share/herdr-flow/artifacts/<TICKET>/<phase>.md`  
Override: `HERDR_FLOW_ARTIFACTS`. Agent kind: `HERDR_FLOW_AGENT_KIND` (default `cursor`).

## Checks

```bash
./scripts/check.sh   # shellcheck + bats
```

## taskwarrior-tui

Shortcut **`w`** → `~/.local/bin/herdr-flow-tui` (configured in `~/.config/taskrc`).

Opens an **fzf** menu (works over ssh; needs a TTY):

| Action | What it does |
|--------|----------------|
| `start:spec` / `plan` / `build` / `review` | Background `herdr-flow start --phase …` |
| `start:auto` | Start using existing `phase` UDA (else spec) |
| `resume` | Focus Herder agent session |
| `open-artifact` | Floating terminal → editor on artifact |
| `next-task` / `phase-done` | TW follow-up / annotate done |
| `ship-pr:create` / `ship-pr:run` | Draft PR task or run open |

Logs: `~/.local/share/herdr-flow/logs/`. Notifications on failures only.

## Board TUI (Go)

Dependency + phase pipeline board (Taskwarrior `depends` + inferred `spec→plan→build→review`):

```bash
make board && make install   # ~/.local/bin/herdr-flow-board
herdr-flow-board
```

See `board/README.md` for keys (`/`, fold, actions → `herdr-flow`).

Install links (already used if you ran setup):

```bash
ln -sfn "$PWD/bin/herdr-flow" ~/.local/bin/herdr-flow
ln -sfn "$PWD/bin/herdr-flow-tui" ~/.local/bin/herdr-flow-tui
```

## Cutover from tw-agent

`w` no longer calls `tw-agent --bg`. Keep `tw-agent` installed until a full manual E2E succeeds; you can temporarily restore the old shortcut in `config/taskrc` if needed.
