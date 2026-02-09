#!/usr/bin/env bats
# Hevy CLI - Cache Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Cache Stats Tests
# ============================================================================

@test "hevy cache stats shows statistics" {
  # Ensure cache is populated
  run_hevy --quiet exercises list --limit 1
  assert_success

  run_hevy cache stats

  assert_success
}

# ============================================================================
# Cache Refresh Tests
# ============================================================================

@test "hevy cache refresh --exercises refreshes exercises" {
  run_hevy --quiet cache refresh --exercises

  assert_success
}

@test "hevy cache refresh --workouts refreshes workouts" {
  run_hevy --quiet cache refresh --workouts

  assert_success
}

@test "hevy cache refresh --routines refreshes routines" {
  run_hevy --quiet cache refresh --routines

  assert_success
}

# ============================================================================
# Cache Clear Tests
# ============================================================================

@test "hevy cache clear clears cache" {
  run_hevy --quiet exercises list --limit 1
  assert_success

  run_hevy cache clear

  assert_success
}

@test "cache auto-refresh works after clear" {
  run_hevy cache clear
  assert_success

  run_hevy --quiet exercises search squat

  assert_success
  assert_output_contains "Squat"
}
