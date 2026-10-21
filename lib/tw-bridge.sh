#!/usr/bin/env bash
# Taskwarrior read/write boundary for herdr-flow.
# shellcheck shell=bash
# Must be sourced after lib/common.sh (provides herdr_flow_die).
#
# Use HERDR_FLOW_TASK to override the task binary (tests use /usr/bin/task to
# bypass profile wrappers that force TASKDATA).

# Expected UDAs (see docs/udas.md): repo phase artifact session branch shipcmd type

tw_bridge_task() {
  local bin="${HERDR_FLOW_TASK:-task}"
  "$bin" "$@"
}

# Quote a UDA value so Taskwarrior does not treat hyphens as date math.
tw_bridge_uda() {
  local key="$1" val="$2"
  printf '%s:"%s"' "$key" "$val"
}

tw_bridge_parse_created_uuid() {
  local out="$1"
  if [[ "$out" =~ ([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

tw_bridge_export() {
  local id="$1"
  local json
  json="$(tw_bridge_task "$id" export 2>/dev/null)" || herdr_flow_die "task not found: $id"
  printf '%s' "$json" | jq -c 'if type=="array" then .[0] // empty else . end' | {
    local obj
    IFS= read -r obj || true
    [[ -n "${obj:-}" && "$obj" != "null" ]] || herdr_flow_die "task not found: $id"
    printf '%s\n' "$obj"
  }
}

tw_bridge_uuid() {
  local id="$1"
  tw_bridge_export "$id" | jq -r '.uuid'
}

tw_bridge_get() {
  local uuid="$1" field="$2"
  local obj
  obj="$(tw_bridge_export "$uuid")"
  case "$field" in
    description | uuid | status | project)
      printf '%s' "$obj" | jq -r --arg f "$field" '.[$f] // empty'
      ;;
    repo | phase | artifact | session | branch | shipcmd | type)
      printf '%s' "$obj" | jq -r --arg f "$field" '.[$f] // empty'
      ;;
    *)
      herdr_flow_die "tw_bridge_get: unknown field: $field"
      ;;
  esac
}

tw_bridge_set() {
  local uuid="$1"
  shift
  [[ $# -gt 0 ]] || herdr_flow_die "tw_bridge_set: need key=value args"
  local args=() pair key val
  for pair in "$@"; do
    if [[ "$pair" == *:* ]]; then
      key="${pair%%:*}"
      val="${pair#*:}"
      # Strip wrapping quotes if caller already quoted
      val="${val#\"}"
      val="${val%\"}"
      args+=("$(tw_bridge_uda "$key" "$val")")
    else
      args+=("$pair")
    fi
  done
  tw_bridge_task "$uuid" modify "${args[@]}" >/dev/null
}

tw_bridge_annotate() {
  local uuid="$1" msg="$2"
  tw_bridge_task "$uuid" annotate "$msg" >/dev/null
}

tw_bridge_require_repo() {
  local uuid="$1"
  local repo
  repo="$(tw_bridge_get "$uuid" repo)"
  [[ -n "$repo" ]] || herdr_flow_die "task $uuid missing UDA repo (local path required)"
  [[ -d "$repo" ]] || herdr_flow_die "task $uuid repo path does not exist: $repo"
  printf '%s' "$repo"
}

# Derive ticket key for branch/artifact/label naming.
# Prefer: jiraid → github/gitlab issue-N → leading KEY-N in description →
# key segment in existing branch → short uuid.
tw_bridge_ticket_key() {
  local uuid="$1"
  local obj key
  obj="$(tw_bridge_export "$uuid")"
  key="$(printf '%s' "$obj" | jq -r '
    def jirakey: test("^[A-Z][A-Z0-9]+-[0-9]+$");
    def branchkey:
      capture("(^|/)(?<k>[A-Za-z][A-Za-z0-9]*-[0-9]+)(-|$)") | .k;
    if ((.jiraid // "") | jirakey) then .jiraid
    elif ((.githubnumber // 0) != 0)
         and ((.githubtype // "") != "pull_request")
      then "issue-\(.githubnumber)"
    elif ((.gitlabnumber // 0) != 0)
         and ((.gitlabtype // "") != "merge_request")
      then "issue-\(.gitlabnumber)"
    elif ((.description // "") | test("^[A-Z][A-Z0-9]+-[0-9]+\\b"))
      then ((.description // "") | capture("^(?<k>[A-Z][A-Z0-9]+-[0-9]+)\\b") | .k)
    elif ((.branch // "") | test("(^|/)([A-Za-z][A-Za-z0-9]*-[0-9]+)(-|$)"))
      then ((.branch // "") | branchkey)
    else empty
    end
  ')"
  if [[ -n "$key" && "$key" != "null" ]]; then
    if [[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then
      printf '%s' "$key"
    else
      printf '%s' "$key" | tr '[:upper:]' '[:lower:]'
    fi
    return 0
  fi
  key="$(printf '%s' "$uuid" | tr -d '-' | cut -c1-8)"
  printf '%s' "$key"
}

tw_bridge_next_phase_name() {
  local phase="$1"
  case "$phase" in
    spec) printf 'plan' ;;
    plan) printf 'build' ;;
    build) printf 'review' ;;
    review) printf '' ;; # ship-pr, not a phase
    *) herdr_flow_die "tw_bridge_next_phase_name: unknown phase: $phase" ;;
  esac
}

tw_bridge_add_task() {
  # Usage: tw_bridge_add_task "$desc" +tag key:"val" ...
  local out new
  out="$(tw_bridge_task rc.verbose=new-uuid add "$@" 2>&1)" || herdr_flow_die "task add failed: $out"
  new="$(tw_bridge_parse_created_uuid "$out")" || herdr_flow_die "could not parse new uuid from: $out"
  printf '%s\n' "$new"
}

# Create follow-up phase task; prints new uuid.
tw_bridge_create_next_phase() {
  local uuid="$1"
  local phase next key repo artifact branch desc new
  phase="$(tw_bridge_get "$uuid" phase)"
  [[ -n "$phase" ]] || herdr_flow_die "task $uuid missing UDA phase"
  next="$(tw_bridge_next_phase_name "$phase")"
  [[ -n "$next" ]] || herdr_flow_die "no next phase after '$phase' (use ship-pr)"

  key="$(tw_bridge_ticket_key "$uuid")"
  repo="$(tw_bridge_get "$uuid" repo)"
  artifact="$(tw_bridge_get "$uuid" artifact)"
  branch="$(tw_bridge_get "$uuid" branch)"
  desc="${next}: ${key}"

  local add_args=("$desc" +herdr_flow "$(tw_bridge_uda phase "$next")")
  [[ -n "$repo" ]] && add_args+=("$(tw_bridge_uda repo "$repo")")
  [[ -n "$artifact" ]] && add_args+=("$(tw_bridge_uda artifact "$artifact")")
  [[ -n "$branch" ]] && add_args+=("$(tw_bridge_uda branch "$branch")")
  # Do not copy session — next phase gets its own agent session
  tw_bridge_add_task "${add_args[@]}"
}

# Create open-PR follow-up; optional shipcmd=… ; prints new uuid.
tw_bridge_create_ship_pr_task() {
  local uuid="$1"
  local shipcmd="${2:-}"
  local key repo branch desc
  key="$(tw_bridge_ticket_key "$uuid")"
  repo="$(tw_bridge_get "$uuid" repo)"
  branch="$(tw_bridge_get "$uuid" branch)"
  desc="ship-pr: ${key}"

  local add_args=("$desc" +herdr_flow +ship_pr)
  [[ -n "$repo" ]] && add_args+=("$(tw_bridge_uda repo "$repo")")
  [[ -n "$branch" ]] && add_args+=("$(tw_bridge_uda branch "$branch")")
  [[ -n "$shipcmd" ]] && add_args+=("$(tw_bridge_uda shipcmd "$shipcmd")")
  tw_bridge_add_task "${add_args[@]}"
}
