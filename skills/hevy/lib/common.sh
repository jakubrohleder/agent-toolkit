#!/bin/bash
# Hevy CLI - Common utilities
# Sourced by bin/hevy and all command files

# ============================================================================
# Constants
# ============================================================================

HEVY_CONFIG_DIR="${HEVY_CONFIG_DIR:-$HOME/.hevy}"
HEVY_CACHE_DB="$HEVY_CONFIG_DIR/cache.db"
HEVY_API_KEY_FILE="$HEVY_CONFIG_DIR/.api_key"
HEVY_BASE_URL="https://api.hevyapp.com"

# ============================================================================
# Output helpers
# ============================================================================

# Colors (disabled if not a terminal or NO_COLOR is set)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Print error and exit
die() {
  echo -e "${RED}error:${NC} $*" >&2
  exit 1
}

# Print warning (doesn't exit)
warn() {
  echo -e "${YELLOW}warning:${NC} $*" >&2
}

# Print info message (respects --quiet)
info() {
  [[ "${HEVY_QUIET:-}" == "true" ]] && return
  echo -e "${BLUE}info:${NC} $*" >&2
}

# Print success message
success() {
  [[ "${HEVY_QUIET:-}" == "true" ]] && return
  echo -e "${GREEN}success:${NC} $*" >&2
}

# Print debug message (only if --verbose)
debug() {
  if [[ "${HEVY_VERBOSE:-}" == "true" ]]; then
    echo -e "${BOLD}debug:${NC} $*" >&2
  fi
  return 0
}

# ============================================================================
# Output formatting
# ============================================================================

# Output data based on format flags
# Usage: output "$json_data" [format_jq_filter]
output() {
  local data="$1"
  local filter="${2:-.}"

  if [[ "${HEVY_JSON:-}" == "true" ]]; then
    # Raw JSON output
    echo "$data" | jq -e "$filter" 2>/dev/null || echo "$data"
  elif [[ "${HEVY_VERBOSE:-}" == "true" ]]; then
    # Pretty-printed JSON
    echo "$data" | jq -e "$filter" 2>/dev/null || echo "$data"
  else
    # Compact output - caller handles formatting
    echo "$data" | jq -r "$filter" 2>/dev/null || echo "$data"
  fi
}

# Format data as aligned table
# Usage: table "header1\theader2" "data1\tdata2" ...
# Or pipe: echo -e "h1\th2\nv1\tv2" | table
table() {
  if [[ $# -gt 0 ]]; then
    # Arguments mode
    printf '%s\n' "$@" | column -t -s $'\t'
  else
    # Pipe mode
    column -t -s $'\t'
  fi
}

# ============================================================================
# Authentication
# ============================================================================

# Get API key from config file
get_api_key() {
  if [[ ! -f "$HEVY_API_KEY_FILE" ]]; then
    die "API key not found. Run: hevy auth <your-api-key>"
  fi

  local key
  key=$(cat "$HEVY_API_KEY_FILE" 2>/dev/null | tr -d '[:space:]')

  if [[ -z "$key" ]]; then
    die "API key file is empty. Run: hevy auth <your-api-key>"
  fi

  echo "$key"
}

# Check if authenticated (doesn't exit, returns status)
is_authenticated() {
  [[ -f "$HEVY_API_KEY_FILE" ]] && [[ -s "$HEVY_API_KEY_FILE" ]]
}

# ============================================================================
# User interaction
# ============================================================================

# Confirmation prompt for destructive operations
# Usage: confirm "Delete routine?" || exit 0
confirm() {
  local prompt="${1:-Continue?}"

  # Skip if --yes flag was set
  if [[ "${HEVY_YES:-}" == "true" ]]; then
    return 0
  fi

  # Can't prompt if not interactive
  if [[ ! -t 0 ]]; then
    die "Cannot prompt for confirmation in non-interactive mode. Use --yes to confirm."
  fi

  echo -en "${YELLOW}$prompt${NC} [y/N] " >&2
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# ============================================================================
# JSON validation helpers
# ============================================================================

# Check if file contains valid JSON
is_valid_json() {
  local file="$1"
  jq -e . "$file" >/dev/null 2>&1
}

# Check for @ symbol in notes (causes API errors)
check_at_symbol() {
  local json="$1"
  if echo "$json" | jq -e '[.. | .notes? // empty | select(contains("@"))] | length > 0' >/dev/null 2>&1; then
    return 1  # Found @ symbol
  fi
  return 0  # No @ symbol
}

# Validate routine JSON structure
validate_routine_json() {
  local file="$1"
  local json

  if [[ ! -f "$file" ]]; then
    die "File not found: $file"
  fi

  json=$(cat "$file")

  # Check valid JSON
  if ! echo "$json" | jq -e . >/dev/null 2>&1; then
    die "Invalid JSON in $file"
  fi

  # Check wrapper present
  if ! echo "$json" | jq -e '.routine' >/dev/null 2>&1; then
    die "Missing 'routine' wrapper. Use: {\"routine\": {...}}"
  fi

  # Check exercises array exists
  if ! echo "$json" | jq -e '.routine.exercises | length > 0' >/dev/null 2>&1; then
    die "Routine must have at least one exercise"
  fi

  # Check for @ symbol in notes
  if ! check_at_symbol "$json"; then
    die "Found @ symbol in notes - replace with 'at' to avoid API errors"
  fi

  # Warn about superset rest placement
  local superset_rest_issue
  superset_rest_issue=$(echo "$json" | jq -e '
    .routine.exercises |
    group_by(.superset_id) |
    .[] | select(.[0].superset_id != null) |
    .[:-1][] | select((.rest_seconds // 0) > 0) |
    .exercise_template_id
  ' 2>/dev/null || true)

  if [[ -n "$superset_rest_issue" ]]; then
    warn "Superset has rest on non-final exercise - only last should have rest"
  fi

  return 0
}

# Strip read-only fields from routine for PUT requests
strip_readonly_fields() {
  local json="$1"
  echo "$json" | jq '
    .routine |= (
      del(.id, .folder_id, .created_at, .updated_at) |
      .exercises = [.exercises[] | del(.index, .title) | .sets = [.sets[] | del(.index)]]
    )
  '
}

# ============================================================================
# Utility functions
# ============================================================================

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure required dependencies
check_dependencies() {
  local missing=()

  command_exists curl || missing+=("curl")
  command_exists jq || missing+=("jq")
  command_exists sqlite3 || missing+=("sqlite3")

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required dependencies: ${missing[*]}"
  fi
}

# Get script directory (where hevy CLI is installed)
get_script_dir() {
  local source="${BASH_SOURCE[0]}"
  while [[ -L "$source" ]]; do
    local dir
    dir=$(cd -P "$(dirname "$source")" && pwd)
    source=$(readlink "$source")
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  cd -P "$(dirname "$source")/.." && pwd
}
