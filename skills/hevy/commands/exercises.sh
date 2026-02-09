#!/bin/bash
# Hevy CLI - Exercises command
# Usage: hevy exercises <subcommand> [options]

show_exercises_help() {
  cat <<'EOF'
hevy exercises - Search and manage exercises

Usage: hevy exercises <command> [options]

Commands:
  search <query>       Search exercises by name (fuzzy match)
  list                 List exercises with optional filters
  get <id>             Get exercise details by ID
  custom               List custom exercises only
  create <json>        Create a custom exercise
  types                List exercise types
  muscles              List muscle groups
  equipment            List equipment types

Options:
  --type <type>        Filter by exercise type (weight_reps, reps_only, duration, distance_duration)
  --muscle <group>     Filter by primary muscle group
  --limit <n>          Limit results (default: 50)
  --help, -h           Show this help

Cache commands:
  hevy cache refresh   Force refresh exercise cache
  hevy cache stats     Show cache statistics
  hevy cache clear     Clear cache

Examples:
  hevy exercises search squat
  hevy exercises search "pull up"
  hevy exercises list --type weight_reps --muscle chest
  hevy exercises get D04AC939
  hevy exercises custom
EOF
}

cmd_main() {
  local subcommand="${1:-}"
  shift 2>/dev/null || true

  case "$subcommand" in
    --help|-h|help)
      show_exercises_help
      ;;
    search|find|s)
      exercises_search "$@"
      ;;
    list|ls)
      exercises_list "$@"
      ;;
    get|show)
      exercises_get "$@"
      ;;
    custom)
      exercises_custom "$@"
      ;;
    create|new|add)
      exercises_create "$@"
      ;;
    types)
      exercises_types
      ;;
    muscles)
      exercises_muscles
      ;;
    equipment)
      exercises_equipment
      ;;
    "")
      show_exercises_help
      ;;
    *)
      # Assume it's a search query
      exercises_search "$subcommand" "$@"
      ;;
  esac
}

# Search exercises by name
exercises_search() {
  local query="$*"

  if [[ -z "$query" ]]; then
    die "Usage: hevy exercises search <query>"
  fi

  debug "Searching for: $query"
  local results
  results=$(cache_search "$query")

  if [[ -z "$results" ]]; then
    info "No exercises found matching: $query"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    # Convert TSV to JSON
    echo "$results" | awk -F'\t' 'BEGIN{print "["} {
      if(NR>1) print ","
      printf "{\"id\":\"%s\",\"title\":\"%s\",\"type\":\"%s\",\"equipment\":\"%s\",\"muscle\":\"%s\",\"is_custom\":%s}", $1, $2, $3, $4, $5, ($6=="1"?"true":"false")
    } END{print "]"}'
  else
    # Format output with header
    {
      echo -e "ID\tTITLE\tTYPE\tEQUIPMENT\tMUSCLE"
      echo "$results" | while IFS=$'\t' read -r id title type equipment muscle is_custom; do
        local custom_marker=""
        [[ "$is_custom" == "1" ]] && custom_marker=" *"
        echo -e "${id}\t${title}${custom_marker}\t${type}\t${equipment}\t${muscle}"
      done
    } | table
    echo ""
    echo "* = custom exercise"
  fi
}

# List exercises with filters
exercises_list() {
  local type_filter=""
  local muscle_filter=""
  local limit=50

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type|-t)
        type_filter="$2"
        shift 2
        ;;
      --muscle|-m)
        muscle_filter="$2"
        shift 2
        ;;
      --limit|-l)
        limit="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local args=()
  [[ -n "$type_filter" ]] && args+=(--type "$type_filter")
  [[ -n "$muscle_filter" ]] && args+=(--muscle "$muscle_filter")

  local results
  results=$(cache_list "${args[@]}" | head -n "$limit")

  if [[ -z "$results" ]]; then
    info "No exercises found"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$results" | awk -F'\t' 'BEGIN{print "["} {
      if(NR>1) print ","
      printf "{\"id\":\"%s\",\"title\":\"%s\",\"type\":\"%s\",\"equipment\":\"%s\",\"muscle\":\"%s\"}", $1, $2, $3, $4, $5
    } END{print "]"}'
  else
    echo -e "ID\tTITLE\tTYPE\tEQUIPMENT\tMUSCLE"
    echo "$results" | table
  fi
}

# Get exercise by ID
exercises_get() {
  local id="$1"

  if [[ -z "$id" ]]; then
    die "Usage: hevy exercises get <id>"
  fi

  local exercise
  exercise=$(cache_get "$id")

  if [[ -z "$exercise" || "$exercise" == "null" ]]; then
    die "Exercise not found: $id"
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$exercise" | jq .
  else
    echo "$exercise" | jq -r '
      "ID: \(.id)",
      "Title: \(.title)",
      "Type: \(.type)",
      "Equipment: \(.equipment // "none")",
      "Primary muscle: \(.primary_muscle_group // "n/a")",
      "Secondary muscles: \(.secondary_muscle_groups // "n/a")",
      "Custom: \(if .is_custom == 1 or .is_custom == true then "yes" else "no" end)"
    '
  fi
}

# List custom exercises only
exercises_custom() {
  local results
  results=$(cache_list --custom)

  if [[ -z "$results" ]]; then
    info "No custom exercises found"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$results" | awk -F'\t' 'BEGIN{print "["} {
      if(NR>1) print ","
      printf "{\"id\":\"%s\",\"title\":\"%s\",\"type\":\"%s\",\"equipment\":\"%s\",\"muscle\":\"%s\"}", $1, $2, $3, $4, $5
    } END{print "]"}'
  else
    echo -e "ID\tTITLE\tTYPE\tEQUIPMENT\tMUSCLE"
    echo "$results" | table
  fi
}

# Create custom exercise
exercises_create() {
  local input="$1"

  if [[ -z "$input" ]]; then
    die "Usage: hevy exercises create <json-file-or-string>"
  fi

  local json
  if [[ -f "$input" ]]; then
    json=$(cat "$input")
  else
    json="$input"
  fi

  # Validate JSON
  if ! echo "$json" | jq -e . >/dev/null 2>&1; then
    die "Invalid JSON"
  fi

  # Ensure wrapper present
  if ! echo "$json" | jq -e '.exercise_template' >/dev/null 2>&1; then
    debug "Adding exercise_template wrapper"
    json=$(echo "$json" | jq '{exercise_template: .}')
  fi

  debug "Creating custom exercise"
  local response
  response=$(api_post "/v1/exercise_templates" "$json") || exit 1

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$response" | jq .
  else
    local id title
    id=$(echo "$response" | jq -r '.exercise_template.id // .id // "unknown"')
    title=$(echo "$response" | jq -r '.exercise_template.title // .title // "unknown"')
    success "Created exercise: $title (ID: $id)"

    # Refresh cache to include new exercise
    info "Refreshing cache..."
    cache_refresh
  fi
}

# List exercise types
exercises_types() {
  echo "Exercise types:"
  echo "  weight_reps      - Weight and reps (squats, bench press)"
  echo "  reps_only        - Reps only, no weight (pull-ups, push-ups)"
  echo "  duration         - Time-based (planks, stretching)"
  echo "  distance_duration - Distance and time (rowing, running)"
}

# List muscle groups
exercises_muscles() {
  cache_muscle_groups
}

# List equipment types
exercises_equipment() {
  cache_equipment_types
}
