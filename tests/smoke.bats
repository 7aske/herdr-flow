#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FLOW="$ROOT/bin/herdr-flow"
}

@test "herdr-flow --help exits 0 and prints Usage" {
  run "$FLOW" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "herdr-flow with no args exits non-zero" {
  run "$FLOW"
  [ "$status" -ne 0 ]
}

@test "herdr-flow unknown command exits non-zero" {
  run "$FLOW" not-a-real-command
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "herdr-flow start without id fails" {
  run "$FLOW" start
  [ "$status" -ne 0 ]
}

@test "herdr-flow open-artifact without id fails" {
  run "$FLOW" open-artifact
  [ "$status" -ne 0 ]
}
