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
}

teardown() {
  tw_test_env_teardown
}

@test "phase-done annotates" {
  uuid="$(tw_bridge_add_task 'PROJ-1 x' \
    "$(tw_bridge_uda phase spec)" \
    "$(tw_bridge_uda artifact /tmp/a.md)")"
  run phases_done "$uuid"
  [ "$status" -eq 0 ]
  ann="$(tw_bridge_export "$uuid" | jq -r '.annotations[0].description // empty')"
  [[ "$ann" == *"DONE phase=spec"* ]]
}

@test "next-task creates plan from spec" {
  REPO_DIR="$(mktemp -d "$TASKDATA/repo.XXXXXX")"
  uuid="$(tw_bridge_add_task 'PROJ-2 x' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    "$(tw_bridge_uda phase spec)" \
    "$(tw_bridge_uda artifact /tmp/spec.md)" \
    "$(tw_bridge_uda branch feature/PROJ-2-x)")"
  new="$(phases_next_task "$uuid")"
  [ "$(tw_bridge_get "$new" phase)" = "plan" ]
}

@test "next-task after review points at ship-pr" {
  uuid="$(tw_bridge_add_task 'PROJ-3 x' "$(tw_bridge_uda phase review)")"
  run phases_next_task "$uuid"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ship-pr"* ]]
}
