#!/usr/bin/env bats
# Hevy CLI - Workout Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Workout List Tests
# ============================================================================

@test "hevy workouts list returns workouts" {
  run_hevy --quiet workouts list

  assert_success
  if [[ "$output" != *"No workouts found"* ]]; then
    assert_table_header "ID" "TITLE" "DATE"
  fi
}

@test "hevy workouts list with --json returns valid JSON" {
  run_hevy --quiet --json workouts list

  assert_success
  assert_valid_json
  assert_json_array
}

@test "hevy workouts list --last N limits results" {
  run_hevy --quiet --json workouts list --last 3

  assert_success
  assert_valid_json

  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -le 3 ]]
}

@test "hevy workouts list --from filters by date" {
  run_hevy --quiet workouts list --from "last month"

  assert_success
}

# ============================================================================
# Workout Get Tests
# ============================================================================

@test "hevy workouts get <id> returns workout details" {
  run_hevy --quiet --json workouts list --last 1
  assert_success

  local workout_id
  workout_id=$(echo "$output" | jq -r '.[0].id // empty')

  if [[ -z "$workout_id" ]]; then
    skip "No workouts available to test"
  fi

  run_hevy --quiet workouts get "$workout_id"

  assert_success
  assert_output_contains "Title:"
  assert_output_contains "ID:"
  assert_output_contains "Date:"
}

@test "hevy workouts get with --json returns valid JSON" {
  run_hevy --quiet --json workouts list --last 1
  assert_success

  local workout_id
  workout_id=$(echo "$output" | jq -r '.[0].id // empty')

  if [[ -z "$workout_id" ]]; then
    skip "No workouts available to test"
  fi

  run_hevy --quiet --json workouts get "$workout_id"

  assert_success
  assert_valid_json
  assert_json_object
  assert_json_has_key ".id"
  assert_json_has_key ".title"
}

# ============================================================================
# Workout Export Tests
# ============================================================================

@test "hevy workouts export --format json outputs valid JSON" {
  run_hevy --quiet workouts export --format json --from "last week"

  assert_success
  assert_valid_json
  assert_json_array
}

@test "hevy workouts export --format csv outputs CSV with header" {
  run_hevy --quiet workouts export --format csv --from "last week"

  assert_success
  assert_output_contains "date,workout_title,exercise,set_num,type,weight_kg,reps"
}

@test "hevy workouts export --format md outputs markdown" {
  run_hevy --quiet workouts export --format md --from "last week"

  assert_success
  assert_output_contains "# Workout History"
}
