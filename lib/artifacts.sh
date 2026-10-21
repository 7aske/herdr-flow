#!/usr/bin/env bash
# Phase artifact paths and editor open helper.
# shellcheck shell=bash
# Must be sourced after lib/common.sh.

artifacts_root() {
  printf '%s' "${HERDR_FLOW_ARTIFACTS:-$HOME/.local/share/herdr-flow/artifacts}"
}

artifacts_sanitize_key() {
  local key="$1"
  [[ -n "$key" ]] || herdr_flow_die "artifacts: empty ticket key"
  # Allow alnum, dot, underscore, hyphen only
  if [[ ! "$key" =~ ^[A-Za-z0-9._-]+$ ]]; then
    herdr_flow_die "artifacts: unsafe ticket key: $key"
  fi
  printf '%s' "$key"
}

artifacts_validate_phase() {
  local phase="$1"
  case "$phase" in
    spec | plan | build | review) ;;
    *) herdr_flow_die "artifacts: invalid phase: $phase" ;;
  esac
}

artifacts_path() {
  local key phase
  key="$(artifacts_sanitize_key "$1")"
  phase="$2"
  artifacts_validate_phase "$phase"
  printf '%s/%s/%s.md' "$(artifacts_root)" "$key" "$phase"
}

artifacts_ensure() {
  local path parent
  path="$(artifacts_path "$1" "$2")"
  parent="$(dirname "$path")"
  mkdir -p "$parent"
  [[ -f "$path" ]] || : >"$path"
  printf '%s\n' "$path"
}

artifacts_open() {
  local path="$1"
  [[ -n "$path" ]] || herdr_flow_die "artifacts_open: empty path"
  [[ -e "$path" ]] || herdr_flow_die "artifacts_open: path does not exist: $path"
  local editor="${EDITOR:-}"
  if [[ -z "$editor" ]]; then
    if command -v nvim >/dev/null 2>&1; then
      editor="nvim"
    else
      editor="vi"
    fi
  fi
  # EDITOR may contain flags; use eval-safe split via array only for simple names —
  # for MVP invoke as a single command name (no spaces).
  if [[ "$editor" == *" "* ]]; then
    herdr_flow_die "artifacts_open: EDITOR with spaces not supported yet: $editor"
  fi
  exec "$editor" "$path"
}
