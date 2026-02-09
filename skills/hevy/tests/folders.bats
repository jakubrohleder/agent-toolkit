#!/usr/bin/env bats
# Hevy CLI - Folder Tests
# Note: The public API does not support folder deletion

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Folder List Tests
# ============================================================================

@test "hevy folders list returns folders" {
  run_hevy --quiet folders list

  assert_success
  if [[ "$output" != *"No folders found"* ]]; then
    assert_table_header "ID" "TITLE" "CREATED"
  fi
}

@test "hevy folders list with --json returns valid JSON" {
  run_hevy --quiet --json folders list

  assert_success
  assert_valid_json
  assert_json_array
}

# ============================================================================
# Folder Create Tests
# ============================================================================

@test "hevy folders create creates a folder" {
  local folder_name
  folder_name=$(test_resource_name)

  run_hevy folders create "$folder_name"
  assert_success
  assert_output_contains "Created folder:"
  assert_output_contains "$folder_name"

  # Verify it appears in list
  run_hevy --quiet --json folders list
  assert_success

  local found
  found=$(echo "$output" | jq --arg name "$folder_name" '[.[] | select(.title == $name)] | length')
  [[ "$found" -ge 1 ]]
}

@test "hevy folders create requires title" {
  run_hevy folders create

  assert_failure
  assert_output_contains "Usage:"
}
