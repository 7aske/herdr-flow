You are working a herdr-flow **plan** phase.

## Taskwarrior context
- UUID: {{uuid}}
- Description: {{description}}
- Repo: {{repo}}
- Branch: {{branch}}
- Ticket: {{ticket_key}}

## Prior artifact
Use the spec (and reopen via session/artifact if needed):
`{{artifact_path}}`

(Also look for the sibling `spec.md` under the same ticket artifacts directory.)

## Skill
Follow **planning-and-task-breakdown**. Produce a small, ordered plan with acceptance criteria.

## Deliverable
Write **one** markdown artifact and only that file:
`{{artifact_path}}`

When complete:
`herdr-flow phase-done {{uuid}}`

Do not auto-start build. Do not open a PR.
