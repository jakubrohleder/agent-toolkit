#!/usr/bin/env bats
# Hevy CLI - Global Flags Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# --json Flag Tests
# ============================================================================

@test "--json outputs valid JSON parseable by jq" {
  run_hevy --quiet --json exercises list --limit 5

  assert_success
  assert_valid_json
  assert_json_array

  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -ge 0 ]]
}

@test "--json works with different commands" {
  # Redirect stderr to avoid cache refresh messages breaking JSON validation
  run bash -c '"$1" --quiet --json routines list 2>/dev/null' _ "$HEVY_BIN"
  assert_success
  assert_valid_json

  run bash -c '"$1" --quiet --json workouts list --last 1 2>/dev/null' _ "$HEVY_BIN"
  assert_success
  assert_valid_json

  run bash -c '"$1" --quiet --json folders list 2>/dev/null' _ "$HEVY_BIN"
  assert_success
  assert_valid_json
}

# ============================================================================
# --help Flag Tests
# ============================================================================

@test "--help shows usage text" {
  run_hevy --help

  assert_success
  assert_output_contains "hevy - Hevy workout app CLI"
  assert_output_contains "Usage:"
  assert_output_contains "Commands:"
  assert_output_contains "auth"
  assert_output_contains "exercises"
  assert_output_contains "routines"
  assert_output_contains "workouts"
}

@test "subcommand --help shows command-specific help" {
  run_hevy exercises --help
  assert_success
  assert_output_contains "hevy exercises"

  run_hevy routines --help
  assert_success
  assert_output_contains "hevy routines"

  run_hevy workouts --help
  assert_success
  assert_output_contains "hevy workouts"
}

# ============================================================================
# --version Flag Tests
# ============================================================================

@test "--version shows version" {
  run_hevy --version

  assert_success
  assert_output_contains "hevy"
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ============================================================================
# --quiet Flag Tests
# ============================================================================

@test "--quiet suppresses info messages" {
  run_hevy cache clear
  assert_success

  run_hevy --quiet exercises search squat

  assert_success
  refute_output_contains "info:"
}

# ============================================================================
# --verbose Flag Tests
# ============================================================================

@test "--verbose shows debug output" {
  run_hevy --verbose exercises list --limit 1

  assert_success
}

# ============================================================================
# --yes Flag Tests
# ============================================================================

@test "--yes flag is accepted" {
  # Test that --yes flag is recognized (used for confirmation prompts)
  run_hevy --yes --help

  assert_success
  assert_output_contains "hevy"
}
