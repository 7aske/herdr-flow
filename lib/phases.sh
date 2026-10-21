#!/usr/bin/env bash
# Manual lifecycle phases: start / resume / prompt render.
# shellcheck shell=bash
# Source after: common, tw-bridge, artifacts, herdr-git.

phases_skill_for() {
  case "$1" in
    spec) printf 'spec-driven-development' ;;
    plan) printf 'planning-and-task-breakdown' ;;
    build) printf 'incremental-implementation' ;;
    review) printf 'code-review-and-quality' ;;
    *) herdr_flow_die "phases: unknown phase: $1" ;;
  esac
}

phases_validate_phase() {
  artifacts_validate_phase "$1"
}

# Agent name for session UDA: [a-z][a-z0-9_-]{0,31}
phases_session_name() {
  local key="$1" phase="$2" raw
  key="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
  raw="hf-${key}-${phase}"
  raw="$(printf '%s' "$raw" | tr -cd 'a-z0-9_-' | cut -c1-32)"
  [[ "$raw" =~ ^[a-z] ]] || raw="h${raw:0:31}"
  printf '%s' "$raw"
}

phases_resolve_phase() {
  local uuid="$1"
  local flag="${2:-}"
  if [[ -n "$flag" ]]; then
    phases_validate_phase "$flag"
    printf '%s' "$flag"
    return 0
  fi
  local phase typ
  phase="$(tw_bridge_get "$uuid" phase)"
  if [[ -n "$phase" ]]; then
    phases_validate_phase "$phase"
    printf '%s' "$phase"
    return 0
  fi
  # Fall back to legacy tw-agent `type` UDA when phase unset
  typ="$(tw_bridge_get "$uuid" type)"
  case "$typ" in
    spec | plan | build | review)
      printf '%s' "$typ"
      return 0
      ;;
    impl) printf 'build'; return 0 ;;
    research) printf 'spec'; return 0 ;;
  esac
  printf 'spec'
}

phases_prompt_template() {
  local phase="$1" root
  root="$(herdr_flow_root)"
  local f="$root/prompts/${phase}.md"
  [[ -f "$f" ]] || herdr_flow_die "missing prompt template: $f"
  cat "$f"
}

phases_prompt_build() {
  local uuid="$1" phase="$2"
  local description repo branch ticket artifact skill
  description="$(tw_bridge_get "$uuid" description)"
  repo="$(tw_bridge_get "$uuid" repo)"
  branch="$(tw_bridge_get "$uuid" branch)"
  ticket="$(tw_bridge_ticket_key "$uuid")"
  artifact="$(tw_bridge_get "$uuid" artifact)"
  skill="$(phases_skill_for "$phase")"
  phases_prompt_template "$phase" \
    | sed \
      -e "s|{{uuid}}|${uuid}|g" \
      -e "s|{{description}}|${description}|g" \
      -e "s|{{repo}}|${repo}|g" \
      -e "s|{{branch}}|${branch}|g" \
      -e "s|{{ticket_key}}|${ticket}|g" \
      -e "s|{{artifact_path}}|${artifact}|g" \
      -e "s|{{skill}}|${skill}|g"
}

phases_herdr() {
  herdr_git_herdr "$@"
}

phases_parse_pane_id() {
  local json="$1"
  printf '%s' "$json" | jq -r '.result.root_pane.pane_id // empty'
}

phases_start() {
  local id="$1"
  local phase_flag="${2:-}"
  local uuid phase key path wt wid session pane tab prompt kind label desc
  uuid="$(tw_bridge_uuid "$id")"
  phase="$(phases_resolve_phase "$uuid" "$phase_flag")"
  tw_bridge_set "$uuid" "phase:$phase"

  key="$(tw_bridge_ticket_key "$uuid")"
  path="$(artifacts_ensure "$key" "$phase")"
  tw_bridge_set "$uuid" "artifact:$path"

  # Opens/creates the *worktree* workspace (not the main repo workspace).
  # Sets HERDR_FLOW_WT_PATH / HERDR_FLOW_WT_WID / HERDR_FLOW_ROOT_{TAB,PANE}.
  # Do not capture in $() — that runs a subshell and drops the globals.
  herdr_git_ensure_for_task "$uuid" "$phase" >/dev/null
  wt="${HERDR_FLOW_WT_PATH:-}"
  wid="${HERDR_FLOW_WT_WID:-}"
  [[ -n "$wid" ]] || herdr_flow_die "phases: missing worktree workspace id after ensure"
  [[ -n "$wt" ]] || herdr_flow_die "phases: missing worktree path after ensure"

  session="$(phases_session_name "$key" "$phase")"
  desc="$(tw_bridge_get "$uuid" description)"
  label="$(herdr_git_worktree_label "$phase" "$key" "$desc")"
  pane="${HERDR_FLOW_ROOT_PANE:-}"
  tab="${HERDR_FLOW_ROOT_TAB:-}"

  # Reuse the worktree's first shell tab/pane so the agent is not in tab 2.
  if [[ -z "$pane" ]]; then
    local tab_json
    tab_json="$(phases_herdr tab create --workspace "$wid" --cwd "$wt" --label "$label" \
      "$(herdr_git_focus_flag)")" \
      || herdr_flow_die "phases: herdr tab create failed"
    pane="$(phases_parse_pane_id "$tab_json")"
    tab="$(printf '%s' "$tab_json" | jq -r '.result.root_pane.tab_id // .result.tab.tab_id // empty')"
  fi
  [[ -n "$pane" ]] || herdr_flow_die "phases: missing pane for agent start"
  if [[ -n "$tab" ]]; then
    phases_herdr tab rename "$tab" "$label" >/dev/null 2>&1 || true
  fi

  kind="${HERDR_FLOW_AGENT_KIND:-cursor}"
  phases_herdr agent start "$session" --kind "$kind" --pane "$pane" >/dev/null \
    || herdr_flow_die "phases: herdr agent start failed (kind=$kind pane=$pane)"

  prompt="$(phases_prompt_build "$uuid" "$phase")"
  # Async by default — do not --wait (keeps CLI snappy).
  phases_herdr agent prompt "$session" "$prompt" >/dev/null \
    || herdr_flow_die "phases: herdr agent prompt failed"

  tw_bridge_set "$uuid" "session:$session"
  printf '%s\n' "$session"
}

phases_resume() {
  local id="$1"
  local uuid session
  uuid="$(tw_bridge_uuid "$id")"
  session="$(tw_bridge_get "$uuid" session)"
  [[ -n "$session" ]] || herdr_flow_die "phases: task $uuid has no session UDA; run start first"
  if ! phases_herdr agent get "$session" >/dev/null 2>&1; then
    herdr_flow_die "phases: session '$session' not found in herdr; re-run start"
  fi
  # resume always focuses the agent session (explicit "go there" action)
  phases_herdr agent focus "$session" >/dev/null
  printf '%s\n' "$session"
}

# Agent-callable: mark phase complete (annotation only; does not start next).
phases_done() {
  local id="$1"
  local uuid phase artifact
  uuid="$(tw_bridge_uuid "$id")"
  phase="$(tw_bridge_get "$uuid" phase)"
  [[ -n "$phase" ]] || herdr_flow_die "phase-done: missing phase UDA"
  artifact="$(tw_bridge_get "$uuid" artifact)"
  tw_bridge_annotate "$uuid" "herdr-flow DONE phase=$phase artifact=${artifact:-none}"
  printf '%s\n' "$uuid"
}

# Create next-phase TW task (or tell human to ship-pr after review).
phases_next_task() {
  local id="$1"
  local uuid phase next new
  uuid="$(tw_bridge_uuid "$id")"
  phase="$(tw_bridge_get "$uuid" phase)"
  [[ -n "$phase" ]] || herdr_flow_die "next-task: missing phase UDA"
  next="$(tw_bridge_next_phase_name "$phase")"
  if [[ -z "$next" ]]; then
    herdr_flow_info "review complete — run: herdr-flow ship-pr $uuid"
    return 0
  fi
  new="$(tw_bridge_create_next_phase "$uuid")"
  herdr_flow_info "next-task $new (phase=$next)"
  printf '%s\n' "$new"
}
