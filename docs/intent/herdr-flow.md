# Intent: herdr-flow

Confirmed via interview-me (2026-10-20).

## Statement of intent

- **Outcome:** Replace the clunky TW→work flow with a Herder-integrated loop: TW ticket → workspace/worktree → phase agents → PR (`gh`/`glab`).
- **User:** Personal daily driver (not a multi-user product yet).
- **Why now:** A similar setup already exists at `~/.local/src/sh/dotfiles/src/tw-agent.sh`; this should replace it, using that script only as behavioral reference, not something to port.
- **Success:** From a TW ticket, run **spec → plan → build → review** (manual between phases), then a separate TW “open PR” task that runs `gh`/`glab`, and ship a GitLab/GitHub PR — and this new flow is what gets used instead of `tw-agent.sh`.
- **Constraint:** MVP is **bash first**, then a more robust rewrite later; state backend is **Taskwarrior** only; phases are **manual**; each phase = **one resumable agent session** + **one artifact** at a stable path (openable via shortcut); workspace = repo, worktree/branch = `feature/<id>-kebab-title`; prompts use TW metadata + the matching lifecycle skill.
- **Out of scope:** Auto-chaining phases; investigate; non-TW state backends (later adapters); opening the PR inside the review agent; adopting the old script’s structure/clunk; a non-bash rewrite in the first cut; affecting ad-hoc non-workflow agents.

## Notes from interview

- Entry: Taskwarrior task (often fed from Jira etc.); local repo path via annotation/UDA.
- Herder: workspace named by repository; worktrees named like the branch (`feature/<jira-id>-kebab-title`).
- Phase handoff: manual by default; agent updates TW (phase, artifact path, session link) and may create the next-phase task (e.g. `plan: JIRA-123`).
- Resume: reopen the **agent session** for a past phase; also shortcut to open the single phase artifact (e.g. `nvim <path>`).
- Artifacts: one MD per phase in a shared local location so tasks can reference them across phases.
- Open PR: separate action after review — ideally a TW task whose command runs `gh` or `glab`.
- Multi-tracker state (Jira, Linear, markdown, GitHub/GitLab as source of truth) is design shape for later; MVP keeps state in Taskwarrior only.
