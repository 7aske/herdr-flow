#!/usr/bin/env bash
# Shared helpers for herdr-flow libraries.
# shellcheck shell=bash

# Echo to the terminal only (no Herdr notification). Successes stay quiet in the UI.
herdr_flow_info() {
  printf 'herdr-flow: %s\n' "$*" >&2
}

# Echo + Herdr notification. Failures only.
# Usage: herdr_flow_notify <title> [body] [sound]
#   sound: none | done | request  (default none)
herdr_flow_notify() {
  local title="${1:-herdr-flow}"
  local body="${2:-}"
  local sound="${3:-none}"
  if [[ -n "$body" ]]; then
    printf 'herdr-flow: %s — %s\n' "$title" "$body" >&2
  else
    printf 'herdr-flow: %s\n' "$title" >&2
  fi
  local bin="${HERDR_FLOW_HERDR:-herdr}"
  if command -v "$bin" >/dev/null 2>&1 || [[ "$bin" == */* && -x "$bin" ]]; then
    if [[ -n "$body" ]]; then
      "$bin" notification show "$title" --body "$body" --sound "$sound" >/dev/null 2>&1 || true
    else
      "$bin" notification show "$title" --sound "$sound" >/dev/null 2>&1 || true
    fi
  fi
}

herdr_flow_die() {
  herdr_flow_notify "herdr-flow FAILED" "$*" "request"
  exit 1
}

herdr_flow_root() {
  # Directory containing bin/ and lib/ (repo root when running from source).
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s' "$here"
}
