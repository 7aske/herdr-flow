#!/usr/bin/env bats

load helpers/tw_env

setup() {
  tw_test_env_setup
  # shellcheck source=/dev/null
  source "$ROOT/lib/herdr-git.sh"
  chmod +x "$ROOT/tests/fixtures/fake-herdr"
  export HERDR_FLOW_HERDR="$ROOT/tests/fixtures/fake-herdr"
  export HERDR_STUB_LOG="$TASKDATA/herdr.log"
  : >"$HERDR_STUB_LOG"

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
  export HERDR_STUB_WT_PATH="$HERDR_STUB_REPO"
  export HERDR_STUB_HAS_WT=0
}

teardown() {
  tw_test_env_teardown
}

@test "herdr_git_slugify strips key and kebabs" {
  [ "$(herdr_git_slugify 'PROJ-9 Add Login Page!!')" = "add-login-page" ]
}

@test "herdr_git_branch_name format" {
  [ "$(herdr_git_branch_name spec PROJ-9 'Add Login')" = "spec/PROJ-9-add-login" ]
}

@test "herdr_git_worktree_label format" {
  [ "$(herdr_git_worktree_label spec issue-10 'Foo Bar')" = "spec:issue-10-foo-bar" ]
}

@test "herdr_git_default_base uses main" {
  [ "$(herdr_git_default_base "$GIT_REPO")" = "main" ]
}

@test "herdr_git_ensure_worktree create sets wid and root tab/pane" {
  herdr_git_ensure_worktree "$GIT_REPO" spec/PROJ-1-x "spec:PROJ-1-x" >/dev/null
  [ "$HERDR_FLOW_WT_PATH" = "$HERDR_STUB_WT_PATH" ]
  [ "$HERDR_FLOW_WT_WID" = "w-stub" ]
  [ "$HERDR_FLOW_ROOT_TAB" = "w-stub:t0" ]
  [ "$HERDR_FLOW_ROOT_PANE" = "w-stub:p0" ]
  grep -q 'worktree create' "$HERDR_STUB_LOG"
  grep -q -- '--no-focus' "$HERDR_STUB_LOG"
}

@test "herdr_git_focus_flag respects HERDR_FLOW_FOCUS" {
  unset HERDR_FLOW_FOCUS
  [ "$(herdr_git_focus_flag)" = "--no-focus" ]
  HERDR_FLOW_FOCUS=1
  [ "$(herdr_git_focus_flag)" = "--focus" ]
}

@test "herdr_git_ensure_for_task sets branch UDA" {
  uuid="$(tw_bridge_add_task 'PROJ-42 Cool Feature' "$(tw_bridge_uda repo "$GIT_REPO")")"
  herdr_git_ensure_for_task "$uuid" spec >/dev/null
  branch="$(tw_bridge_get "$uuid" branch)"
  [ "$branch" = "spec/PROJ-42-cool-feature" ]
  [ -n "$HERDR_FLOW_WT_WID" ]
  [ "$HERDR_FLOW_ROOT_PANE" = "w-stub:p0" ]
  grep -q 'worktree create' "$HERDR_STUB_LOG"
  grep -q 'spec:PROJ-42-cool-feature' "$HERDR_STUB_LOG"
}

@test "herdr_git_ensure_worktree reopen keeps root pane" {
  export HERDR_STUB_HAS_WT=1
  export HERDR_STUB_BRANCH=spec/PROJ-1-reuse
  # Linked path must exist for reopen branch
  mkdir -p "$TASKDATA/linked-wt"
  export HERDR_STUB_WT_PATH="$TASKDATA/linked-wt"
  # Stub list returns path — ensure directory exists
  herdr_git_ensure_worktree "$GIT_REPO" spec/PROJ-1-reuse "spec:PROJ-1-reuse" >/dev/null
  [ -n "$HERDR_FLOW_WT_PATH" ]
  [ "$HERDR_FLOW_ROOT_TAB" = "w-stub:t0" ]
  [ "$HERDR_FLOW_ROOT_PANE" = "w-stub:p0" ]
  grep -q 'worktree open' "$HERDR_STUB_LOG"
}
