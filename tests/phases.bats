#!/usr/bin/env bats

load helpers/tw_env

setup() {
  tw_test_env_setup
  # shellcheck source=/dev/null
  source "$ROOT/lib/artifacts.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/herdr-git.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/phases.sh"
  chmod +x "$ROOT/tests/fixtures/fake-herdr"
  export HERDR_FLOW_HERDR="$ROOT/tests/fixtures/fake-herdr"
  export HERDR_STUB_LOG="$TASKDATA/herdr.log"
  : >"$HERDR_STUB_LOG"
  export HERDR_FLOW_ARTIFACTS="$TASKDATA/artifacts"

  GIT_REPO="$TASKDATA/sample-repo"
  mkdir -p "$GIT_REPO"
  git -C "$GIT_REPO" init -b main >/dev/null
  git -C "$GIT_REPO" config user.email test@example.com
  git -C "$GIT_REPO" config user.name test
  echo hi >"$GIT_REPO/README"
  git -C "$GIT_REPO" add README
  git -C "$GIT_REPO" commit -m init >/dev/null
  HERDR_STUB_REPO="$(cd "$GIT_REPO" && pwd)"
  export HERDR_STUB_REPO
}

teardown() {
  tw_test_env_teardown
}

@test "phases_session_name is herdr-safe" {
  name="$(phases_session_name PROJ-9 spec)"
  [[ "$name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]
  [ "$name" = "hf-proj-9-spec" ]
}

@test "phases_prompt_build fills artifact path" {
  uuid="$(tw_bridge_add_task 'PROJ-3 feature' \
    "$(tw_bridge_uda repo "$GIT_REPO")" \
    "$(tw_bridge_uda phase spec)" \
    "$(tw_bridge_uda artifact /tmp/x/spec.md)" \
    "$(tw_bridge_uda branch spec/PROJ-3-feature)")"
  prompt="$(phases_prompt_build "$uuid" spec)"
  [[ "$prompt" == *"/tmp/x/spec.md"* ]]
  [[ "$prompt" == *"spec-driven-development"* || "$prompt" == *"phase-done"* ]]
}

@test "phases_start sets session and calls herdr agent" {
  uuid="$(tw_bridge_add_task 'PROJ-5 Cool Thing' "$(tw_bridge_uda repo "$GIT_REPO")")"
  export HERDR_STUB_HAS_WT=0
  export HERDR_STUB_WT_PATH="$GIT_REPO"
  # Avoid $() so any nested globals remain visible in failure diagnostics
  phases_start "$uuid" spec >"$TASKDATA/session.out"
  session="$(cat "$TASKDATA/session.out")"
  [ "$session" = "hf-proj-5-spec" ]
  [ "$(tw_bridge_get "$uuid" session)" = "hf-proj-5-spec" ]
  [ "$(tw_bridge_get "$uuid" phase)" = "spec" ]
  art="$(tw_bridge_get "$uuid" artifact)"
  [[ "$art" == *"/PROJ-5/spec.md" ]]
  grep -q 'worktree create' "$HERDR_STUB_LOG"
  grep -q 'tab rename' "$HERDR_STUB_LOG"
  grep -q 'agent start' "$HERDR_STUB_LOG"
  grep -q 'agent prompt' "$HERDR_STUB_LOG"
  # Agent reuses first worktree tab — no second tab, no close
  if grep -q 'tab create' "$HERDR_STUB_LOG"; then
    echo "unexpected tab create (agent should reuse root pane)" >&2
    return 1
  fi
  if grep -q 'tab close' "$HERDR_STUB_LOG"; then
    echo "unexpected tab close" >&2
    return 1
  fi
}

@test "phases_resume focuses existing session" {
  uuid="$(tw_bridge_add_task 'PROJ-6 x' \
    "$(tw_bridge_uda repo "$GIT_REPO")" \
    "$(tw_bridge_uda session hf-proj-6-spec)")"
  run phases_resume "$uuid"
  [ "$status" -eq 0 ]
  grep -q 'agent focus' "$HERDR_STUB_LOG"
}

@test "CLI start --phase plan" {
  uuid="$(tw_bridge_add_task 'PROJ-8 plan me' "$(tw_bridge_uda repo "$GIT_REPO")")"
  run "$ROOT/bin/herdr-flow" start "$uuid" --phase plan
  [ "$status" -eq 0 ]
  [ "$(tw_bridge_get "$uuid" phase)" = "plan" ]
}
