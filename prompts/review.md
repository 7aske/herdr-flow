You are working a herdr-flow **review** phase.

## Taskwarrior context
- UUID: {{uuid}}
- Description: {{description}}
- Repo: {{repo}}
- Branch: {{branch}}
- Ticket: {{ticket_key}}

## Skill
Follow **code-review-and-quality**. Review the branch diff against the plan/spec artifacts.

## Deliverable
Write **one** review markdown artifact:
`{{artifact_path}}`

When complete:
`herdr-flow phase-done {{uuid}}`

Do **not** open a PR/MR. After review, the human runs `herdr-flow ship-pr`.
