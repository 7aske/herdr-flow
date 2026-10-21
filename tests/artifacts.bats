#!/usr/bin/env bats

load helpers/tw_env

setup() {
  tw_test_env_setup
  # shellcheck source=/dev/null
  source "$ROOT/lib/artifacts.sh"
  export HERDR_FLOW_ARTIFACTS="$TASKDATA/artifacts"
}

teardown() {
  tw_test_env_teardown
}

@test "artifacts_path layout" {
  [ "$(artifacts_path PROJ-1 spec)" = "$HERDR_FLOW_ARTIFACTS/PROJ-1/spec.md" ]
}

@test "artifacts_sanitize rejects unsafe keys" {
  run artifacts_sanitize_key '../etc'
  [ "$status" -ne 0 ]
}

@test "artifacts_ensure creates file" {
  path="$(artifacts_ensure PROJ-2 plan)"
  [ -f "$path" ]
  [ "$path" = "$HERDR_FLOW_ARTIFACTS/PROJ-2/plan.md" ]
}

@test "artifacts_open invokes EDITOR" {
  path="$(artifacts_ensure PROJ-3 build)"
  export EDITOR="$TASKDATA/fake-editor"
  cat >"$EDITOR" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${HERDR_FLOW_ARTIFACTS}/editor.args"
EOF
  chmod +x "$EDITOR"
  # artifacts_open execs — run in subshell via bash -c
  run bash -c "source '$ROOT/lib/common.sh'; source '$ROOT/lib/artifacts.sh'; artifacts_open '$path'"
  [ "$status" -eq 0 ]
  [ "$(cat "$HERDR_FLOW_ARTIFACTS/editor.args")" = "$path" ]
}

@test "open-artifact CLI resolves from TW UDAs" {
  path="$(artifacts_ensure PROJ-8 spec)"
  uuid="$(tw_bridge_add_task 'PROJ-8 feature' \
    "$(tw_bridge_uda repo "$REPO_DIR")" \
    "$(tw_bridge_uda phase spec)" \
    "$(tw_bridge_uda artifact "$path")")"
  export EDITOR="$TASKDATA/fake-editor"
  cat >"$EDITOR" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${HERDR_FLOW_ARTIFACTS}/cli.args"
EOF
  chmod +x "$EDITOR"
  run "$ROOT/bin/herdr-flow" open-artifact "$uuid"
  [ "$status" -eq 0 ]
  [ "$(cat "$HERDR_FLOW_ARTIFACTS/cli.args")" = "$path" ]
}
