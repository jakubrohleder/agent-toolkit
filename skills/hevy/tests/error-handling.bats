#!/usr/bin/env bats
# Hevy CLI - Error Handling Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Missing Arguments Tests
# ============================================================================

@test "missing required arguments show usage" {
  run_hevy exercises get
  assert_failure
  assert_output_contains "Usage:"

  run_hevy routines rename
  assert_failure
  assert_output_contains "Usage:"

  run_hevy workouts get
  assert_failure
  assert_output_contains "Usage:"
}

# ============================================================================
# Invalid Command Tests
# ============================================================================

@test "invalid subcommand shows error" {
  run_hevy notacommand

  assert_failure
  assert_output_contains "Unknown command"
}

@test "invalid exercises subcommand falls back to search" {
  run_hevy exercises unknownsubcmd

  # Unknown subcommands for exercises are treated as search queries
  assert_success
}

@test "invalid routines subcommand shows error" {
  run_hevy routines notasubcmd

  assert_failure
  assert_output_contains "Unknown routines command"
}

# ============================================================================
# Invalid ID Tests
# ============================================================================

@test "invalid routine ID returns error" {
  run_hevy routines get "invalid-id-that-does-not-exist-12345"

  assert_failure
}

@test "invalid workout ID returns error" {
  run_hevy workouts get "invalid-workout-id-12345"

  assert_failure
}

# ============================================================================
# Invalid JSON Tests
# ============================================================================

@test "invalid JSON file shows validation error" {
  local bad_file="$BATS_TEST_TMPDIR/not_json.txt"
  echo "this is not json" > "$bad_file"

  run_hevy routines create "$bad_file"

  assert_failure
  assert_output_contains "Invalid JSON"
}

@test "missing routine wrapper shows error" {
  local bad_file="$BATS_TEST_TMPDIR/no_wrapper.json"
  cat > "$bad_file" <<'EOF'
{
  "title": "Test",
  "exercises": []
}
EOF

  run_hevy routines create "$bad_file"

  assert_failure
  assert_output_contains "Missing 'routine' wrapper"
}

@test "routine without exercises shows error" {
  local bad_file="$BATS_TEST_TMPDIR/no_exercises.json"
  cat > "$bad_file" <<'EOF'
{
  "routine": {
    "title": "Empty Routine",
    "exercises": []
  }
}
EOF

  run_hevy routines create "$bad_file"

  assert_failure
  assert_output_contains "must have at least one exercise"
}

@test "nonexistent file shows error" {
  run_hevy routines create "/path/to/nonexistent/file.json"

  assert_failure
  assert_output_contains "not found"
}
