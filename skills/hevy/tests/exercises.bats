#!/usr/bin/env bats
# Hevy CLI - Exercise Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Exercise Search Tests
# ============================================================================

@test "hevy exercises search <query> returns matching exercises" {
  run_hevy --quiet exercises search squat

  assert_success
  assert_table_header "ID" "TITLE" "TYPE"
  assert_output_contains "Squat"
}

@test "hevy exercises search with --json returns valid JSON" {
  run_hevy --quiet --json exercises search bench

  assert_success
  assert_valid_json
  assert_json_array
}

# ============================================================================
# Exercise List Tests
# ============================================================================

@test "hevy exercises list returns exercises" {
  run_hevy --quiet exercises list

  assert_success
  assert_table_header "ID" "TITLE" "TYPE" "EQUIPMENT" "MUSCLE"
  assert_line_count_min 2
}

@test "hevy exercises list --type <type> filters by type" {
  run_hevy --quiet exercises list --type weight_reps

  assert_success
  assert_table_header "ID" "TITLE"
  assert_output_contains "weight_reps"
}

@test "hevy exercises list --muscle <muscle> filters by muscle" {
  run_hevy --quiet exercises list --muscle chest

  assert_success
  assert_table_header "ID" "TITLE"
}

# ============================================================================
# Exercise Get Tests
# ============================================================================

@test "hevy exercises get <id> returns exercise details" {
  run_hevy --quiet exercises get D04AC939

  assert_success
  assert_output_contains "ID: D04AC939"
  assert_output_contains "Title:"
  assert_output_contains "Type:"
}

@test "hevy exercises get with --json returns valid JSON" {
  run_hevy --quiet --json exercises get D04AC939

  assert_success
  assert_valid_json
  assert_json_object
  assert_json_has_key ".id"
  assert_json_has_key ".title"
}

# ============================================================================
# Exercise Reference Commands
# ============================================================================

@test "hevy exercises types shows type reference" {
  run_hevy exercises types

  assert_success
  assert_output_contains "weight_reps"
  assert_output_contains "reps_only"
  assert_output_contains "duration"
  assert_output_contains "distance_duration"
}

@test "hevy exercises muscles shows muscle groups" {
  run_hevy --quiet exercises muscles

  assert_success
  assert_output_contains "chest"
}

@test "hevy exercises equipment shows equipment types" {
  run_hevy --quiet exercises equipment

  assert_success
  assert_output_contains "barbell"
}
