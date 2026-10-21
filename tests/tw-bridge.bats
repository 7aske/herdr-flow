#!/usr/bin/env bats

load helpers/tw_env

setup() {
  tw_test_env_setup
}

teardown() {
  tw_test_env_teardown
}

@test "tw_bridge_uuid and get/set UDAs" {
  uuid="$(tw_bridge_add_task 'PROJ-99 do the thing' "$(tw_bridge_uda repo "$REPO_DIR")")"
  tw_bridge_set "$uuid" phase:spec artifact:/tmp/a.md session:sess-1 branch:feature/PROJ-99-do-the-thing
  [ "$(tw_bridge_get "$uuid" phase)" = "spec" ]
  [ "$(tw_bridge_get "$uuid" artifact)" = "/tmp/a.md" ]
  [ "$(tw_bridge_get "$uuid" session)" = "sess-1" ]
  [ "$(tw_bridge_get "$uuid" repo)" = "$REPO_DIR" ]
  [ "$(tw_bridge_ticket_key "$uuid")" = "PROJ-99" ]
}

@test "tw_bridge_ticket_key uses github issue number" {
  uuid="$(tw_bridge_add_task 'Globalne tekstualne i spacing' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    githubnumber:10 \
    "$(tw_bridge_uda githubtype issue)")"
  [ "$(tw_bridge_ticket_key "$uuid")" = "issue-10" ]
}

@test "tw_bridge_ticket_key falls back to branch segment" {
  uuid="$(tw_bridge_add_task 'no tracker key here' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    "$(tw_bridge_uda branch feature/issue-10-globalne-tekstualne)")"
  [ "$(tw_bridge_ticket_key "$uuid")" = "issue-10" ]
}

@test "tw_bridge_require_repo fails when missing" {
  uuid="$(tw_bridge_add_task 'no repo here')"
  run tw_bridge_require_repo "$uuid"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing UDA repo"* ]]
}

@test "tw_bridge_require_repo fails when path missing" {
  uuid="$(tw_bridge_add_task 'bad repo' "$(tw_bridge_uda repo /no/such/path/herdr-flow)")"
  run tw_bridge_require_repo "$uuid"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "tw_bridge_create_next_phase copies refs and sets phase" {
  uuid="$(tw_bridge_add_task 'PROJ-7 feature' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    "$(tw_bridge_uda phase spec)" \
    "$(tw_bridge_uda artifact /tmp/spec.md)" \
    "$(tw_bridge_uda branch feature/PROJ-7-feature)")"
  new="$(tw_bridge_create_next_phase "$uuid")"
  [ -n "$new" ]
  [ "$(tw_bridge_get "$new" phase)" = "plan" ]
  [ "$(tw_bridge_get "$new" repo)" = "$REPO_DIR" ]
  [ "$(tw_bridge_get "$new" artifact)" = "/tmp/spec.md" ]
  [ "$(tw_bridge_get "$new" branch)" = "feature/PROJ-7-feature" ]
  [[ "$(tw_bridge_get "$new" description)" == plan:* ]]
}

@test "tw_bridge_create_next_phase after review fails" {
  uuid="$(tw_bridge_add_task 'PROJ-1 x' "$(tw_bridge_uda repo "$REPO_DIR")" "$(tw_bridge_uda phase review)")"
  run tw_bridge_create_next_phase "$uuid"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ship-pr"* ]]
}

@test "tw_bridge_create_ship_pr_task sets shipcmd" {
  uuid="$(tw_bridge_add_task 'PROJ-2 x' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    "$(tw_bridge_uda branch feature/PROJ-2-x)")"
  new="$(tw_bridge_create_ship_pr_task "$uuid" 'gh pr create --draft')"
  [ "$(tw_bridge_get "$new" shipcmd)" = "gh pr create --draft" ]
  [ "$(tw_bridge_get "$new" repo)" = "$REPO_DIR" ]
}
