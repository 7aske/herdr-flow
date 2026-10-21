#!/usr/bin/env bash
# Open GitHub PR / GitLab MR after review (separate from review agent).
# shellcheck shell=bash
# Source after: common, tw-bridge, herdr-git.

ship_pr_detect_host() {
  local repo="$1" url
  url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  if printf '%s' "$url" | grep -qiE 'github\.com|github\.'; then
    printf 'github'
  elif printf '%s' "$url" | grep -qiE 'gitlab\.com|gitlab\.'; then
    printf 'gitlab'
  else
    herdr_flow_die "ship-pr: cannot detect github/gitlab from origin: ${url:-none} (set remote or extend detector)"
  fi
}

ship_pr_build_command() {
  local repo="$1" branch="$2" title="$3"
  local draft="${4:-1}" # 1=draft
  local host
  host="$(ship_pr_detect_host "$repo")"
  title="${title//\"/\\\"}"

  case "$host" in
    github)
      if [[ "$draft" == "1" ]]; then
        printf 'gh pr create --draft --head %q --title %q' "$branch" "$title"
      else
        printf 'gh pr create --head %q --title %q' "$branch" "$title"
      fi
      ;;
    gitlab)
      if [[ "$draft" == "1" ]]; then
        printf 'glab mr create --draft --source-branch %q --title %q --yes' "$branch" "$title"
      else
        printf 'glab mr create --source-branch %q --title %q --yes' "$branch" "$title"
      fi
      ;;
  esac
}

ship_pr_push_if_needed() {
  local repo="$1" branch="$2"
  if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null; then
    return 0
  fi
  git -C "$repo" push -u origin "$branch"
}

# Create TW follow-up with shipcmd; prints new uuid.
ship_pr_create_task() {
  local uuid="$1"
  local draft="${2:-1}"
  local repo branch title cmd
  repo="$(tw_bridge_require_repo "$uuid")"
  branch="$(tw_bridge_get "$uuid" branch)"
  [[ -n "$branch" ]] || herdr_flow_die "ship-pr: missing branch UDA"
  title="$(tw_bridge_get "$uuid" description)"
  cmd="$(ship_pr_build_command "$repo" "$branch" "$title" "$draft")"
  tw_bridge_create_ship_pr_task "$uuid" "$cmd"
}

ship_pr_run() {
  local uuid="$1"
  local do_push="${2:-1}"
  local draft="${3:-1}"
  local repo branch cmd ship_uuid
  repo="$(tw_bridge_require_repo "$uuid")"
  branch="$(tw_bridge_get "$uuid" branch)"
  [[ -n "$branch" ]] || herdr_flow_die "ship-pr: missing branch UDA"

  cmd="$(tw_bridge_get "$uuid" shipcmd)"
  if [[ -z "$cmd" ]]; then
    ship_uuid="$(ship_pr_create_task "$uuid" "$draft")"
    cmd="$(tw_bridge_get "$ship_uuid" shipcmd)"
    herdr_flow_info "created ship-pr task $ship_uuid"
  fi
  [[ -n "$cmd" ]] || herdr_flow_die "ship-pr: empty shipcmd"

  # Prefer worktree path if branch is checked out elsewhere
  local wt
  wt="$(herdr_git_worktree_path_for_branch "$repo" "$branch" || true)"
  local cwd="$repo"
  [[ -n "$wt" && -d "$wt" ]] && cwd="$wt"

  if [[ "$do_push" == "1" ]]; then
    ship_pr_push_if_needed "$cwd" "$branch"
  fi

  # shellcheck disable=SC2086
  (cd "$cwd" && eval "$cmd")
}
