# Taskwarrior UDAs for herdr-flow

Add these to your Taskwarrior config (e.g. `~/.taskrc` or an include) if missing.

Already common on this machine: `repo`, `branch`, `type`.

```ini
uda.phase.type=string
uda.phase.label=Phase

uda.artifact.type=string
uda.artifact.label=Artifact

uda.session.type=string
uda.session.label=Session

uda.shipcmd.type=string
uda.shipcmd.label=ShipCmd
```

| UDA | Purpose |
|-----|---------|
| `repo` | Absolute path to local git repository |
| `phase` | `spec` \| `plan` \| `build` \| `review` |
| `artifact` | Absolute path to this phase’s single markdown artifact |
| `session` | Herder agent/tab identity for resume |
| `branch` | Git branch, e.g. `spec/PROJ-123-short-title` (Herder label uses `spec:PROJ-123-short-title`) |
| `shipcmd` | Runnable `gh`/`glab` command for open-PR follow-up tasks |
| `type` | Optional; may mirror phase for tooling compatibility |

Tags used by herdr-flow: `+herdr_flow`, `+ship_pr`.
