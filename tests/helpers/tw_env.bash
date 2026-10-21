#!/usr/bin/env bash
# Isolated Taskwarrior + herdr-flow lib load for bats.

tw_test_env_setup() {
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  export HERDR_FLOW_ROOT="$ROOT"
  # Bypass ~/.local/bin/task profile wrapper
  export HERDR_FLOW_TASK=/usr/bin/task

  TASKDATA="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/herdr-flow-tw.XXXXXX")"
  export TASKDATA
  export TASKRC="$TASKDATA/taskrc"
  {
    printf 'data.location=%s\n' "$TASKDATA"
    cat <<'EOF'
uda.repo.type=string
uda.repo.label=Repo
uda.branch.type=string
uda.branch.label=Branch
uda.type.type=string
uda.type.label=Type
uda.phase.type=string
uda.phase.label=Phase
uda.artifact.type=string
uda.artifact.label=Artifact
uda.session.type=string
uda.session.label=Session
uda.shipcmd.type=string
uda.shipcmd.label=ShipCmd
uda.jiraid.type=string
uda.jiraid.label=JiraId
uda.githubnumber.type=numeric
uda.githubnumber.label=GitHub#
uda.githubtype.type=string
uda.githubtype.label=GitHubType
uda.gitlabnumber.type=numeric
uda.gitlabnumber.label=GitLab#
uda.gitlabtype.type=string
uda.gitlabtype.label=GitLabType
confirmation=off
EOF
  } >"$TASKRC"

  # shellcheck source=/dev/null
  source "$ROOT/lib/common.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/tw-bridge.sh"

  REPO_DIR="$(mktemp -d "$TASKDATA/repo.XXXXXX")"
  mkdir -p "$REPO_DIR"
}

tw_test_env_teardown() {
  [[ -n "${TASKDATA:-}" && -d "$TASKDATA" ]] && rm -rf "$TASKDATA"
}
