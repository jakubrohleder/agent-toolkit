#!/usr/bin/env bats
# Hevy CLI - Routine Tests
# Note: The public API does not support routine deletion

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Routine List Tests
# ============================================================================

@test "hevy routines list returns routines" {
  run_hevy --quiet routines list

  assert_success
  # Either shows routines or "No routines found"
  if [[ "$output" != *"No routines found"* ]]; then
    assert_table_header "ID" "TITLE" "FOLDER"
  fi
}

@test "hevy routines list with --json returns valid JSON" {
  run_hevy --quiet --json routines list

  assert_success
  assert_valid_json
  assert_json_array
}

# ============================================================================
# Routine Get Tests
# ============================================================================

@test "hevy routines get <id> returns routine details" {
  run_hevy --quiet --json routines list
  assert_success

  local routine_id
  routine_id=$(echo "$output" | jq -r '.[0].id // empty')

  if [[ -z "$routine_id" ]]; then
    skip "No routines available to test"
  fi

  run_hevy --quiet routines get "$routine_id"

  assert_success
  assert_output_contains "Title:"
  assert_output_contains "ID:"
}

# ============================================================================
# Routine Template Tests
# ============================================================================

@test "hevy routines template outputs valid JSON template" {
  run_hevy routines template

  assert_success
  # Extract just the JSON part (up to the closing brace)
  local json_part
  json_part=$(echo "$output" | sed -n '/^{/,/^}/p')
  echo "$json_part" | jq -e '.routine.exercises' >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

# ============================================================================
# Routine Create Tests
# ============================================================================

@test "hevy routines create creates a routine" {
  local test_name
  test_name=$(test_resource_name)

  local routine_file="$BATS_TEST_TMPDIR/test_routine.json"
  create_test_routine_json "$test_name" > "$routine_file"

  run_hevy routines create "$routine_file"
  assert_success
  assert_output_contains "Created routine:"
  assert_output_contains "$test_name"
}

@test "hevy routines create validates JSON structure" {
  local bad_file="$BATS_TEST_TMPDIR/bad_routine.json"
  cat > "$bad_file" <<'EOF'
{
  "routine": {
    "title": "Bad Routine"
  }
}
EOF

  run_hevy routines create "$bad_file"
  assert_failure
  assert_output_contains "must have at least one exercise"
}

# ============================================================================
# Routine Update Tests
# ============================================================================

@test "hevy routines update updates a routine" {
  # Create a routine first
  local test_name
  test_name=$(test_resource_name)

  local routine_file="$BATS_TEST_TMPDIR/update_create.json"
  create_test_routine_json "$test_name" > "$routine_file"

  run_hevy routines create "$routine_file"
  assert_success

  local routine_id
  routine_id=$(extract_id_from_output "$output")
  [[ -n "$routine_id" ]]

  # Build an updated routine JSON with a new title and extra set
  local updated_name="Updated_${test_name}"
  local update_file="$BATS_TEST_TMPDIR/update_routine.json"
  cat > "$update_file" <<EOF
{
  "routine": {
    "title": "$updated_name",
    "folder_id": null,
    "exercises": [
      {
        "exercise_template_id": "D04AC939",
        "superset_id": null,
        "rest_seconds": 120,
        "notes": "",
        "sets": [
          {
            "type": "normal",
            "weight_kg": 100,
            "reps": 5
          },
          {
            "type": "normal",
            "weight_kg": 110,
            "reps": 3
          }
        ]
      }
    ]
  }
}
EOF

  run_hevy routines update "$routine_id" "$update_file"
  assert_success
  assert_output_contains "Updated routine:"
  assert_output_contains "$updated_name"
}

@test "hevy routines update with --json returns JSON response" {
  # Create a routine first
  local test_name
  test_name=$(test_resource_name)

  local routine_file="$BATS_TEST_TMPDIR/update_json_create.json"
  create_test_routine_json "$test_name" > "$routine_file"

  run_hevy routines create "$routine_file"
  assert_success

  local routine_id
  routine_id=$(extract_id_from_output "$output")
  [[ -n "$routine_id" ]]

  # Update with --json flag
  local update_file="$BATS_TEST_TMPDIR/update_json.json"
  create_test_routine_json "JSONUpdate_${test_name}" > "$update_file"

  run_hevy --json routines update "$routine_id" "$update_file"
  assert_success
  assert_valid_json
}

@test "hevy routines update fails with missing args" {
  run_hevy routines update
  assert_failure
  assert_output_contains "Usage:"
}

@test "hevy routines update fails with missing file" {
  run_hevy routines update "fake-id" "/nonexistent/file.json"
  assert_failure
  assert_output_contains "File not found"
}

# ============================================================================
# Routine Rename Tests
# ============================================================================

@test "hevy routines rename updates routine title" {
  # Create a fresh routine to rename (avoids data issues with existing routines)
  local test_name
  test_name=$(test_resource_name)

  local routine_file="$BATS_TEST_TMPDIR/rename_test_routine.json"
  create_test_routine_json "$test_name" > "$routine_file"

  run_hevy routines create "$routine_file"
  assert_success

  local routine_id
  routine_id=$(extract_id_from_output "$output")
  [[ -n "$routine_id" ]]

  # Now rename it
  local new_name="Renamed_${test_name}"
  run_hevy routines rename "$routine_id" "$new_name"

  assert_success
  assert_output_contains "Renamed to:"
}

# ============================================================================
# Routine Duplicate Tests
# ============================================================================

@test "hevy routines duplicate creates a copy" {
  # Get an existing routine
  run_hevy --quiet --json routines list
  assert_success

  local routine_id
  routine_id=$(echo "$output" | jq -r '.[0].id // empty')

  if [[ -z "$routine_id" ]]; then
    skip "No routines available to test"
  fi

  local dup_name="Copy_$(test_resource_name)"
  run_hevy routines duplicate "$routine_id" --title "$dup_name"

  assert_success
  assert_output_contains "Created duplicate:"
}
