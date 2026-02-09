#!/usr/bin/env bash
# Hevy CLI Test Helper
# Common setup, teardown, and utility functions for BATS tests
# No external dependencies - uses plain BATS assertions

# ============================================================================
# Test Environment Setup
# ============================================================================

# Setup isolated test environment with API key from real config
setup_test_env() {
  # Get the hevy binary location
  HEVY_BIN="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/hevy"

  # Verify hevy binary exists
  if [[ ! -x "$HEVY_BIN" ]]; then
    echo "Error: hevy binary not found at $HEVY_BIN" >&2
    exit 1
  fi

  # Create isolated config directory for tests
  export HEVY_TEST_CONFIG_DIR="$BATS_TEST_TMPDIR/.hevy"
  mkdir -p "$HEVY_TEST_CONFIG_DIR"

  # Copy API key from real config (required for real API tests)
  local real_api_key_file="$HOME/.hevy/.api_key"
  if [[ -f "$real_api_key_file" ]]; then
    cp "$real_api_key_file" "$HEVY_TEST_CONFIG_DIR/.api_key"
    chmod 600 "$HEVY_TEST_CONFIG_DIR/.api_key"
  else
    echo "Error: No API key found at $real_api_key_file" >&2
    echo "Run 'hevy auth <your-api-key>' to authenticate first" >&2
    exit 1
  fi

  # Export config dir for hevy CLI
  export HEVY_CONFIG_DIR="$HEVY_TEST_CONFIG_DIR"

  # Initialize resource tracking file
  export HEVY_TEST_RESOURCES="$BATS_TEST_TMPDIR/.test_resources"
  : > "$HEVY_TEST_RESOURCES"
}

# ============================================================================
# Resource Management
# ============================================================================

# Generate unique test resource name
test_resource_name() {
  local timestamp=$(date +%s)
  local random=$(( RANDOM % 10000 ))
  echo "BATS_TEST_${timestamp}_${random}"
}

# Track a resource for cleanup
track_resource() {
  local type="$1"
  local id="$2"
  echo "${type}:${id}" >> "$HEVY_TEST_RESOURCES"
}

# Cleanup all tracked resources
cleanup_resources() {
  if [[ ! -f "$HEVY_TEST_RESOURCES" ]]; then
    return 0
  fi

  local line type id
  while IFS=: read -r type id; do
    case "$type" in
      routine)
        "$HEVY_BIN" --yes routines delete "$id" 2>/dev/null || true
        ;;
      folder)
        "$HEVY_BIN" --yes folders delete "$id" 2>/dev/null || true
        ;;
    esac
  done < "$HEVY_TEST_RESOURCES"

  rm -f "$HEVY_TEST_RESOURCES"
}

# ============================================================================
# Hevy CLI Wrapper
# ============================================================================

# Run hevy command with test config
run_hevy() {
  run "$HEVY_BIN" "$@"
}

# ============================================================================
# Assertions (plain bash, no external libs)
# ============================================================================

# Assert command succeeded (exit code 0)
assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success (exit 0), got exit code: $status"
    echo "Output: $output"
    return 1
  fi
}

# Assert command failed (exit code != 0)
assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected failure, but command succeeded"
    echo "Output: $output"
    return 1
  fi
}

# Assert output contains substring
assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert output does not contain substring
refute_output_contains() {
  local unexpected="$1"
  if [[ "$output" == *"$unexpected"* ]]; then
    echo "Expected output NOT to contain: $unexpected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert output is valid JSON
assert_valid_json() {
  if ! echo "$output" | jq -e . >/dev/null 2>&1; then
    echo "Output is not valid JSON:"
    echo "$output"
    return 1
  fi
}

# Assert output is a JSON array
assert_json_array() {
  if ! echo "$output" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "Output is not a JSON array:"
    echo "$output"
    return 1
  fi
}

# Assert output is a JSON object
assert_json_object() {
  if ! echo "$output" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "Output is not a JSON object:"
    echo "$output"
    return 1
  fi
}

# Assert JSON has a specific key
assert_json_has_key() {
  local key="$1"
  if ! echo "$output" | jq -e "$key" >/dev/null 2>&1; then
    echo "JSON does not have key: $key"
    echo "$output"
    return 1
  fi
}

# Assert output has table header columns
assert_table_header() {
  local first_line
  first_line=$(echo "$output" | head -n1)
  for col in "$@"; do
    if [[ "$first_line" != *"$col"* ]]; then
      echo "Table header missing column: $col"
      echo "First line: $first_line"
      return 1
    fi
  done
}

# Assert minimum line count
assert_line_count_min() {
  local min="$1"
  local count
  count=$(echo "$output" | wc -l | tr -d ' ')
  if [[ "$count" -lt "$min" ]]; then
    echo "Expected at least $min lines, got $count"
    return 1
  fi
}

# ============================================================================
# JSON Template Helpers
# ============================================================================

# Create a minimal routine JSON for testing
create_test_routine_json() {
  local title="${1:-Test Routine}"
  cat <<EOF
{
  "routine": {
    "title": "$title",
    "folder_id": null,
    "exercises": [
      {
        "exercise_template_id": "D04AC939",
        "superset_id": null,
        "rest_seconds": 90,
        "notes": "",
        "sets": [
          {
            "type": "normal",
            "weight_kg": 100,
            "reps": 5
          }
        ]
      }
    ]
  }
}
EOF
}

# ============================================================================
# Extract Helpers
# ============================================================================

# Extract ID from success message like "Created routine: Title (ID: abc-123)"
extract_id_from_output() {
  local text="$1"
  echo "$text" | grep -oE '\(ID: [^)]+\)' | sed 's/(ID: //' | sed 's/)//'
}

# Extract first ID from a list (assumes table format with ID in first column)
extract_first_id() {
  local text="$1"
  echo "$text" | tail -n +2 | head -1 | awk '{print $1}'
}
