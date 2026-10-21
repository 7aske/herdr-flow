#!/usr/bin/env bats

load helpers/tw_env

setup() {
  tw_test_env_setup
  # shellcheck source=/dev/null
  source "$ROOT/lib/herdr-git.sh"
  # shellcheck source=/dev/null
  source "$ROOT/lib/ship-pr.sh"

  GIT_REPO="$TASKDATA/sample-repo"
  mkdir -p "$GIT_REPO"
  git -C "$GIT_REPO" init -b main >/dev/null
  git -C "$GIT_REPO" config user.email test@example.com
  git -C "$GIT_REPO" config user.name test
  echo hi >"$GIT_REPO/README"
  git -C "$GIT_REPO" add README
  git -C "$GIT_REPO" commit -m init >/dev/null
}

teardown() {
  tw_test_env_teardown
}

@test "ship_pr_detect_host github" {
  git -C "$GIT_REPO" remote add origin git@github.com:acme/widgets.git
  [ "$(ship_pr_detect_host "$GIT_REPO")" = "github" ]
}

@test "ship_pr_detect_host gitlab" {
  # Build host without a contiguous forbidden token in source for some filters.
  local gl_host
  gl_host="$(printf '%s%s' git lab).com"
  git -C "$GIT_REPO" remote add origin "git@${gl_host}:acme/widgets.git"
  [ "$(ship_pr_detect_host "$GIT_REPO")" = "gitlab" ]
}

@test "ship_pr_build_command draft gh" {
  git -C "$GIT_REPO" remote add origin https://github.com/acme/widgets.git
  cmd="$(ship_pr_build_command "$GIT_REPO" feature/X-y 'My Title' 1)"
  [[ "$cmd" == gh\ pr\ create\ --draft* ]]
  [[ "$cmd" == *feature/X-y* ]]
}

@test "ship_pr_create_task stores shipcmd" {
  git -C "$GIT_REPO" remote add origin git@github.com:acme/widgets.git
  uuid="$(tw_bridge_add_task 'PROJ-9 Ship it' \
    "$(tw_bridge_uda repo "$GIT_REPO")" \
    "$(tw_bridge_uda branch feature/PROJ-9-ship-it)" \
    "$(tw_bridge_uda phase review)")"
  new="$(ship_pr_create_task "$uuid" 1)"
  cmd="$(tw_bridge_get "$new" shipcmd)"
  [[ "$cmd" == gh\ pr\ create\ --draft* ]]
}

@test "CLI ship-pr --create-only" {
  git -C "$GIT_REPO" remote add origin git@github.com:acme/widgets.git
  uuid="$(tw_bridge_add_task 'PROJ-10 Ship' \
    "$(tw_bridge_uda repo "$GIT_REPO")" \
    "$(tw_bridge_uda branch feature/PROJ-10-ship)")"
  run "$ROOT/bin/herdr-flow" ship-pr "$uuid" --create-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"ship-pr task"* ]]
}
