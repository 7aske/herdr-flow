#!/usr/bin/env bash
# Herder workspace + git worktree helpers for herdr-flow.
# shellcheck shell=bash
# Must be sourced after lib/common.sh and lib/tw-bridge.sh.
#
# HERDR_FLOW_HERDR overrides the herdr binary (tests stub it).
#
# After ensure_worktree / ensure_for_task, these globals are set:
#   HERDR_FLOW_WT_PATH   — checkout path
#   HERDR_FLOW_WT_WID    — herdr workspace id for that worktree
#   HERDR_FLOW_ROOT_TAB  — first shell tab id (rename + start agent here)
#   HERDR_FLOW_ROOT_PANE — first shell pane id

herdr_git_herdr() {
  local bin="${HERDR_FLOW_HERDR:-herdr}"
  "$bin" "$@"
}

# Default: do not steal focus from taskwarrior-tui / SSH. Set HERDR_FLOW_FOCUS=1 to focus.
herdr_git_focus_flag() {
  if [[ "${HERDR_FLOW_FOCUS:-0}" == "1" ]]; then
    printf '%s' '--focus'
  else
    printf '%s' '--no-focus'
  fi
}

herdr_git_repo_from_task() {
  tw_bridge_require_repo "$1"
}

herdr_git_default_base() {
  local repo="$1" ref
  if ref="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    printf '%s' "${ref#origin/}"
    return 0
  fi
  if git -C "$repo" show-ref --verify --quiet refs/heads/main; then
    printf 'main'
    return 0
  fi
  if git -C "$repo" show-ref --verify --quiet refs/heads/master; then
    printf 'master'
    return 0
  fi
  herdr_flow_die "herdr-git: cannot determine default branch in $repo"
}

herdr_git_slugify() {
  local text="$1" slug
  text="$(printf '%s' "$text" | sed -E 's/^[A-Z][A-Z0-9]+-[0-9]+[[:space:]]*//')"
  slug="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
  slug="${slug:0:40}"
  slug="${slug%-}"
  [[ -n "$slug" ]] || slug="work"
  printf '%s' "$slug"
}

# Git branch: <action>/<id>-<slug>  (colon is invalid in git ref names)
herdr_git_branch_name() {
  local action="$1" key="$2" title="$3" slug
  [[ -n "$action" ]] || herdr_flow_die "herdr-git: empty action"
  [[ -n "$key" ]] || herdr_flow_die "herdr-git: empty ticket key"
  slug="$(herdr_git_slugify "$title")"
  printf '%s/%s-%s' "$action" "$key" "$slug"
}

# Herder worktree/workspace label: <action>:<id>-<slug>
herdr_git_worktree_label() {
  local action="$1" key="$2" title="$3" slug
  [[ -n "$action" ]] || herdr_flow_die "herdr-git: empty action"
  [[ -n "$key" ]] || herdr_flow_die "herdr-git: empty ticket key"
  slug="$(herdr_git_slugify "$title")"
  printf '%s:%s-%s' "$action" "$key" "$slug"
}

herdr_git_workspace_name() {
  basename "$1"
}

herdr_git_root_tab_from_json() {
  printf '%s' "$1" | jq -r '.result.root_pane.tab_id // .result.workspace.active_tab_id // empty'
}

herdr_git_root_pane_from_json() {
  printf '%s' "$1" | jq -r '.result.root_pane.pane_id // empty'
}

herdr_git_apply_worktree_json() {
  local json="$1" err="${2:-herdr-git: bad worktree json}"
  HERDR_FLOW_WT_PATH="$(printf '%s' "$json" | jq -r '.result.worktree.path // .result.root_pane.cwd // empty')"
  HERDR_FLOW_WT_WID="$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id // empty')"
  HERDR_FLOW_ROOT_TAB="$(herdr_git_root_tab_from_json "$json")"
  HERDR_FLOW_ROOT_PANE="$(herdr_git_root_pane_from_json "$json")"
  [[ -n "$HERDR_FLOW_WT_PATH" && -n "$HERDR_FLOW_WT_WID" ]] || herdr_flow_die "$err: $json"
  export HERDR_FLOW_WT_PATH HERDR_FLOW_WT_WID HERDR_FLOW_ROOT_TAB HERDR_FLOW_ROOT_PANE
}

# "wid\tpath" for an existing linked worktree on branch, or empty.
herdr_git_lookup_worktree() {
  local repo="$1" branch="$2"
  herdr_git_herdr worktree list --cwd "$repo" --trust-repository 2>/dev/null \
    | jq -r --arg b "$branch" '
        .result.worktrees[]?
        | select(.branch == $b and .is_linked_worktree == true)
        | "\(.open_workspace_id // "")\t\(.path)"
      ' | head -n1
}

herdr_git_worktree_path_for_branch() {
  local repo="$1" branch="$2"
  git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$branch" '
    /^worktree / { path=$2 }
    /^branch / { if ($2 == b) { print path; exit } }
  '
}

herdr_git_is_main_checkout() {
  local repo="$1" path="$2" main
  main="$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  [[ -n "$main" && "$(realpath "$path" 2>/dev/null || printf '%s' "$path")" == "$(realpath "$main" 2>/dev/null || printf '%s' "$main")" ]]
}

# Ensure worktree workspace for branch. Sets HERDR_FLOW_WT_* globals; prints path.
herdr_git_ensure_worktree() {
  local repo="$1" branch="$2" label="${3:-$2}"
  local base path row create_json
  repo="$(cd "$repo" && pwd)"
  [[ -n "$branch" ]] || herdr_flow_die "herdr-git: empty branch"
  base="$(herdr_git_default_base "$repo")"
  HERDR_FLOW_ROOT_TAB=""
  HERDR_FLOW_ROOT_PANE=""
  export HERDR_FLOW_ROOT_TAB HERDR_FLOW_ROOT_PANE

  # Prefer herdr's worktree registry
  row="$(herdr_git_lookup_worktree "$repo" "$branch" || true)"
  if [[ -n "$row" ]]; then
    path="${row#*$'\t'}"
    if [[ -n "$path" && -d "$path" ]]; then
      create_json="$(herdr_git_herdr worktree open --cwd "$repo" --branch "$branch" \
        --label "$label" "$(herdr_git_focus_flag)" --trust-repository)" \
        || herdr_flow_die "herdr-git: worktree open failed for $branch"
      herdr_git_apply_worktree_json "$create_json" "herdr-git: worktree open missing path/id"
      printf '%s\n' "$HERDR_FLOW_WT_PATH"
      return 0
    fi
  fi

  path="$(herdr_git_worktree_path_for_branch "$repo" "$branch")"
  if [[ -n "$path" && -d "$path" ]] && herdr_git_is_main_checkout "$repo" "$path"; then
    # Branch is the main checkout — plain workspace; agent reuses first tab
    create_json="$(herdr_git_herdr workspace create --cwd "$path" --label "$label" \
      "$(herdr_git_focus_flag)")" \
      || herdr_flow_die "herdr-git: workspace create failed"
    HERDR_FLOW_WT_PATH="$path"
    HERDR_FLOW_WT_WID="$(printf '%s' "$create_json" | jq -r '.result.workspace.workspace_id // empty')"
    HERDR_FLOW_ROOT_TAB="$(herdr_git_root_tab_from_json "$create_json")"
    HERDR_FLOW_ROOT_PANE="$(herdr_git_root_pane_from_json "$create_json")"
    [[ -n "$HERDR_FLOW_WT_WID" ]] || herdr_flow_die "herdr-git: workspace create missing id"
    export HERDR_FLOW_WT_PATH HERDR_FLOW_WT_WID HERDR_FLOW_ROOT_TAB HERDR_FLOW_ROOT_PANE
    printf '%s\n' "$HERDR_FLOW_WT_PATH"
    return 0
  fi

  if [[ -n "$path" && -d "$path" ]]; then
    create_json="$(herdr_git_herdr worktree open --path "$path" --branch "$branch" \
      --label "$label" "$(herdr_git_focus_flag)" --trust-repository)" \
      || herdr_flow_die "herdr-git: worktree open failed for $path"
    herdr_git_apply_worktree_json "$create_json" "herdr-git: worktree open missing path/id"
    printf '%s\n' "$HERDR_FLOW_WT_PATH"
    return 0
  fi

  # Fresh linked worktree — herdr chooses path; first tab/pane used for the agent
  create_json="$(herdr_git_herdr worktree create --cwd "$repo" --branch "$branch" \
    --base "$base" --label "$label" "$(herdr_git_focus_flag)" --trust-repository)" \
    || herdr_flow_die "herdr-git: worktree create failed for $branch"
  herdr_git_apply_worktree_json "$create_json" "herdr-git: worktree create missing path/id"
  printf '%s\n' "$HERDR_FLOW_WT_PATH"
}

# Ensure worktree for task. Optional action (phase) names branch/label when branch UDA unset.
herdr_git_ensure_for_task() {
  local uuid="$1"
  local action="${2:-spec}"
  local repo key desc branch label existing
  repo="$(herdr_git_repo_from_task "$uuid")"
  existing="$(tw_bridge_get "$uuid" branch)"
  key="$(tw_bridge_ticket_key "$uuid")"
  desc="$(tw_bridge_get "$uuid" description)"
  label="$(herdr_git_worktree_label "$action" "$key" "$desc")"
  if [[ -n "$existing" ]]; then
    branch="$existing"
  else
    branch="$(herdr_git_branch_name "$action" "$key" "$desc")"
  fi
  # No $() — preserve HERDR_FLOW_WT_* globals from ensure_worktree
  herdr_git_ensure_worktree "$repo" "$branch" "$label" >/dev/null
  tw_bridge_set "$uuid" "branch:$branch"
  printf '%s\n' "${HERDR_FLOW_WT_PATH:-}"
}
