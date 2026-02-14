#!/bin/bash
# Hevy CLI - Routines command
# Usage: hevy routines <subcommand> [options]

show_routines_help() {
  cat <<'EOF'
hevy routines - Manage workout routines

Usage: hevy routines <command> [options]

Commands:
  list                     List all routines
  get <id>                 Get routine details
  create <json>            Create routine from JSON file(s)
  update <id> <json>       Update routine from JSON file
  rename <id> <title>      Rename a routine
  move <id> --folder <id>  Move routine to folder
  duplicate <id>           Duplicate a routine
  template                 Output minimal JSON template

Options:
  --folder <id>            Filter by folder (for list) or target folder (for create/move)
  --title <title>          New title (for duplicate)
  --dir <path>             Create from all JSON files in directory
  --help, -h               Show this help

Examples:
  hevy routines list
  hevy routines list --folder 12345
  hevy routines get abc-123-def
  hevy routines template > my-routine.json
  hevy routines create my-routine.json
  hevy routines create my-routine.json --folder 12345
  hevy routines create --dir /tmp/routines/
  hevy routines update abc-123 updated-routine.json
  hevy routines rename abc-123 "New Title"
  hevy routines duplicate abc-123 --title "Copy of Routine"

Note: Deleting routines is not supported via the API. Delete routines manually in the Hevy app.
EOF
}

cmd_main() {
  local subcommand="${1:-list}"
  shift 2>/dev/null || true

  case "$subcommand" in
    --help|-h|help)
      show_routines_help
      ;;
    list|ls)
      routines_list "$@"
      ;;
    get|show)
      routines_get "$@"
      ;;
    create|new|add)
      routines_create "$@"
      ;;
    update|edit)
      routines_update "$@"
      ;;
    rename)
      routines_rename "$@"
      ;;
    move)
      routines_move "$@"
      ;;
    duplicate|dup|copy)
      routines_duplicate "$@"
      ;;
    template|tpl)
      routines_template
      ;;
    *)
      die "Unknown routines command: $subcommand. Run 'hevy routines --help'"
      ;;
  esac
}

# List all routines
routines_list() {
  local folder_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --folder|-f)
        folder_id="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local routines
  routines=$(paginate_all "/v1/routines" "routines") || exit 1

  # Filter by folder if specified
  if [[ -n "$folder_id" ]]; then
    routines=$(echo "$routines" | jq --arg fid "$folder_id" '[.[] | select(.folder_id == ($fid | tonumber))]')
  fi

  local count
  count=$(echo "$routines" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    info "No routines found"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$routines" | jq .
  else
    echo -e "ID\tTITLE\tFOLDER\tEXERCISES\tUPDATED"
    echo "$routines" | jq -r '.[] | [
      .id,
      .title,
      (.folder_id // "none"),
      (.exercises | length),
      (.updated_at | split("T")[0])
    ] | @tsv' | table
  fi
}

# Get routine by ID
routines_get() {
  local id="$1"

  if [[ -z "$id" ]]; then
    die "Usage: hevy routines get <id>"
  fi

  local response
  response=$(api_get "/v1/routines/$id") || exit 1

  # API returns {"routine": {...}} object for single item
  local routine
  routine=$(echo "$response" | jq 'if .routine | type == "array" then .routine[0] else .routine end')

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$routine" | jq .
  else
    # Display routine details
    echo "$routine" | jq -r '
      "Title: \(.title)",
      "ID: \(.id)",
      "Folder: \(.folder_id // "none")",
      "Created: \(.created_at | split("T")[0])",
      "Updated: \(.updated_at | split("T")[0])",
      "",
      "Exercises:"
    '

    # Format exercises
    echo "$routine" | jq -r '.exercises[] |
      "  \(.index + 1). \(.title // .exercise_template_id)",
      "     Type: \(.superset_id | if . != null then "superset \(.)" else "sequential" end)",
      "     Sets: \(.sets | length)",
      "     Rest: \(.rest_seconds)s",
      if .notes and .notes != "" then "     Notes: \(.notes)" else empty end,
      ""
    '
  fi
}

# Create routine(s) from JSON file(s)
routines_create() {
  local files=()
  local folder_id=""
  local dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --folder|-f)
        folder_id="$2"
        shift 2
        ;;
      --dir|-d)
        dir="$2"
        shift 2
        ;;
      -*)
        shift
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  # Collect files from --dir
  if [[ -n "$dir" ]]; then
    if [[ ! -d "$dir" ]]; then
      die "Directory not found: $dir"
    fi
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$dir" -maxdepth 1 -name '*.json' -print0 | sort -z)
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    die "Usage: hevy routines create <json-file>... [--folder <id>] [--dir <path>]"
  fi

  local total=${#files[@]}
  local created=0
  local failed=0

  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      warn "File not found: $file"
      ((failed++))
      continue
    fi

    # Validate JSON
    if ! validate_routine_json "$file"; then
      ((failed++))
      continue
    fi

    local json
    json=$(cat "$file")

    # Inject folder_id if provided
    if [[ -n "$folder_id" ]]; then
      json=$(echo "$json" | jq --arg fid "$folder_id" '.routine.folder_id = ($fid | tonumber)')
    fi

    # Rate limit delay between API calls for bulk creates
    if [[ $created -gt 0 ]]; then
      debug "Waiting 2s between API calls..."
      sleep 2
    fi

    debug "Creating routine from $file ($((created + failed + 1))/$total)"
    local response
    if ! response=$(api_post "/v1/routines" "$json"); then
      warn "Failed to create routine from $file"
      ((failed++))
      continue
    fi

    # Update cache with new routine
    local routine
    routine=$(echo "$response" | jq 'if .routine | type == "array" then .routine[0] else .routine end')
    cache_routine_upsert "$routine"

    if [[ "$HEVY_JSON" == "true" ]]; then
      echo "$response" | jq .
    else
      local id title
      id=$(echo "$routine" | jq -r '.id // "unknown"')
      title=$(echo "$routine" | jq -r '.title // "unknown"')
      success "Created routine: $title (ID: $id)"
    fi

    ((created++))
  done

  if [[ $total -gt 1 ]]; then
    info "Bulk create: $created succeeded, $failed failed (of $total)"
  fi

  # Exit with error if all files failed
  if [[ $created -eq 0 ]]; then
    return 1
  fi
}

# Update routine from JSON file
routines_update() {
  local id="$1"
  local file="$2"

  if [[ -z "$id" || -z "$file" ]]; then
    die "Usage: hevy routines update <id> <json-file>"
  fi

  if [[ ! -f "$file" ]]; then
    die "File not found: $file"
  fi

  # Validate JSON
  validate_routine_json "$file"

  local json
  json=$(cat "$file")

  # Strip read-only fields
  json=$(strip_readonly_fields "$json")

  debug "Updating routine $id from $file"
  local response
  response=$(api_put "/v1/routines/$id" "$json") || exit 1

  # Update cache
  local routine
  routine=$(echo "$response" | jq 'if .routine | type == "array" then .routine[0] else .routine end')
  cache_routine_upsert "$routine"

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$response" | jq .
  else
    local title
    title=$(echo "$routine" | jq -r '.title // "unknown"')
    success "Updated routine: $title (ID: $id)"
  fi
}

# Rename a routine
routines_rename() {
  local id="$1"
  local new_title="$2"

  if [[ -z "$id" || -z "$new_title" ]]; then
    die "Usage: hevy routines rename <id> <new-title>"
  fi

  # Fetch current routine
  local response
  response=$(api_get "/v1/routines/$id") || exit 1

  # Update title and strip read-only fields
  local update_json
  update_json=$(echo "$response" | jq --arg title "$new_title" '
    (if .routine | type == "array" then .routine[0] else .routine end) |
    .title = $title |
    del(.id, .folder_id, .created_at, .updated_at) |
    .exercises = [.exercises[] | del(.index, .title) | .sets = [.sets[] | del(.index)]] |
    {routine: .}
  ')

  debug "Renaming routine $id to: $new_title"
  local result
  result=$(api_put "/v1/routines/$id" "$update_json") || exit 1

  # Update cache with renamed routine
  local routine
  routine=$(echo "$result" | jq 'if .routine | type == "array" then .routine[0] else .routine end')
  cache_routine_upsert "$routine"

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$result" | jq .
  else
    local final_title
    final_title=$(echo "$routine" | jq -r '.title // "unknown"')
    success "Renamed to: $final_title"
  fi
}

# Move routine to folder
routines_move() {
  local id="$1"
  shift
  local folder_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --folder|-f)
        folder_id="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -z "$id" || -z "$folder_id" ]]; then
    die "Usage: hevy routines move <id> --folder <folder-id>"
  fi

  # Fetch current routine
  local response
  response=$(api_get "/v1/routines/$id") || exit 1

  # Strip read-only fields (folder_id will be set by API based on URL, but we can't set it in body)
  # Note: The Hevy API doesn't support moving via PUT - this is a limitation
  # We'll need to create a new routine in the target folder and delete the old one

  warn "Note: Hevy API doesn't support moving routines directly."
  info "To move a routine, duplicate it to the target folder, then delete the original manually in the Hevy app."
}

# Duplicate a routine
routines_duplicate() {
  local id="$1"
  shift 2>/dev/null || true
  local new_title=""
  local folder_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title|-t)
        new_title="$2"
        shift 2
        ;;
      --folder|-f)
        folder_id="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -z "$id" ]]; then
    die "Usage: hevy routines duplicate <id> [--title <title>] [--folder <id>]"
  fi

  # Fetch original routine
  local response
  response=$(api_get "/v1/routines/$id") || exit 1

  local original_title
  original_title=$(echo "$response" | jq -r 'if .routine | type == "array" then .routine[0].title else .routine.title end')

  # Use provided title or generate one
  if [[ -z "$new_title" ]]; then
    new_title="Copy of $original_title"
  fi

  # Create new routine JSON (strip IDs and read-only fields)
  local new_json
  new_json=$(echo "$response" | jq --arg title "$new_title" '
    (if .routine | type == "array" then .routine[0] else .routine end) |
    .title = $title |
    del(.id, .created_at, .updated_at) |
    .exercises = [.exercises[] | del(.index, .title) | .sets = [.sets[] | del(.index)]] |
    {routine: .}
  ')

  # Add folder_id if specified
  if [[ -n "$folder_id" ]]; then
    new_json=$(echo "$new_json" | jq --arg fid "$folder_id" '.routine.folder_id = ($fid | tonumber)')
  fi

  debug "Creating duplicate: $new_title"
  local result
  result=$(api_post "/v1/routines" "$new_json") || exit 1

  # Update cache with new routine
  local routine
  routine=$(echo "$result" | jq 'if .routine | type == "array" then .routine[0] else .routine end')
  cache_routine_upsert "$routine"

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$result" | jq .
  else
    local new_id
    new_id=$(echo "$routine" | jq -r '.id // "unknown"')
    success "Created duplicate: $new_title (ID: $new_id)"
  fi
}

# Output routine JSON template
routines_template() {
  cat <<'EOF'
{
  "routine": {
    "title": "My Routine",
    "folder_id": null,
    "exercises": [
      {
        "exercise_template_id": "D04AC939",
        "superset_id": null,
        "rest_seconds": 120,
        "notes": "",
        "sets": [
          {
            "type": "warmup",
            "weight_kg": 60,
            "reps": 10
          },
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
  echo ""
  info "Template notes:" >&2
  echo "  - exercise_template_id: Use 'hevy exercises search <name>' to find IDs" >&2
  echo "  - folder_id: Use 'hevy folders list' to get folder IDs (or null for no folder)" >&2
  echo "  - Set types: warmup, normal, failure, dropset" >&2
  echo "  - Set properties depend on exercise type:" >&2
  echo "      weight_reps: weight_kg, reps" >&2
  echo "      reps_only: reps (no weight!)" >&2
  echo "      duration: duration_seconds" >&2
  echo "      distance_duration: distance_meters, duration_seconds" >&2
  echo "      short_distance_weight: distance_meters, weight_kg (e.g. Farmers Walk, Sled Push)" >&2
  echo "  - superset_id: null for sequential, same integer for grouped exercises" >&2
  echo "  - reps: null for max effort / AMRAP sets" >&2
}
