You are working a herdr-flow **build** phase.

## Taskwarrior context
- UUID: {{uuid}}
- Description: {{description}}
- Repo: {{repo}}
- Branch: {{branch}}
- Ticket: {{ticket_key}}

## Plan
Follow the plan artifact (sibling `plan.md` under the ticket artifacts dir). Summary path for this phase notes:
`{{artifact_path}}`

## Skill
Follow **incremental-implementation** and **test-driven-development** where behavior changes.

## Deliverable
Implement on the current branch/worktree. Also write a short build notes markdown to:
`{{artifact_path}}`

When complete:
`herdr-flow phase-done {{uuid}}`

Do not open a PR (that is `herdr-flow ship-pr` after review).
