#!/bin/bash
# Hevy CLI - Workouts command
# Usage: hevy workouts <subcommand> [options]

show_workouts_help() {
  cat <<'EOF'
hevy workouts - View completed workout history

Usage: hevy workouts <command> [options]

Commands:
  list                     List completed workouts
  get <id>                 Get workout details
  by-routine <routine-id>  Find workouts using a specific routine
  export                   Export workout history

Options:
  --from <date>            Start date (YYYY-MM-DD or natural: "yesterday", "last week")
  --to <date>              End date (YYYY-MM-DD or natural)
  --last <n>               Limit to most recent N workouts
  --format <fmt>           Export format: json, md, csv (default: json)
  --help, -h               Show this help

Date formats:
  YYYY-MM-DD               ISO date (2024-01-15)
  today                    Current day
  yesterday                Previous day
  N days ago               e.g., "3 days ago"
  last week                7 days ago
  last month               30 days ago

Examples:
  hevy workouts list
  hevy workouts list --from "last week"
  hevy workouts list --from 2024-01-01 --to 2024-01-31
  hevy workouts get abc-123-def
  hevy workouts by-routine routine-id-123
  hevy workouts by-routine routine-id-123 --last 5
  hevy workouts export --format md --from "last month"
EOF
}

cmd_main() {
  local subcommand="${1:-list}"
  shift 2>/dev/null || true

  case "$subcommand" in
    --help|-h|help)
      show_workouts_help
      ;;
    list|ls)
      workouts_list "$@"
      ;;
    get|show)
      workouts_get "$@"
      ;;
    by-routine|routine)
      workouts_by_routine "$@"
      ;;
    export)
      workouts_export "$@"
      ;;
    *)
      die "Unknown workouts command: $subcommand. Run 'hevy workouts --help'"
      ;;
  esac
}

# List completed workouts
workouts_list() {
  local from_date=""
  local to_date=""
  local limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from|-f)
        from_date=$(parse_date "$2")
        shift 2
        ;;
      --to|-t)
        to_date=$(parse_date "$2")
        shift 2
        ;;
      --last|-l|-n)
        limit="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local workouts

  # Use cache when no date filters (cache has all workouts)
  # Date filters require API since cache may not have complete history
  if [[ -z "$from_date" && -z "$to_date" ]]; then
    workouts=$(cache_workouts_list "" "" "$limit")
  else
    # Fetch from API for date-filtered queries
    workouts=$(paginate_all "/v1/workouts" "workouts") || exit 1

    # Upsert fetched workouts into cache for future use
    cache_workouts_upsert "$workouts"

    # Filter by date range
    if [[ -n "$from_date" ]]; then
      workouts=$(echo "$workouts" | jq --arg from "$from_date" '[.[] | select(.start_time >= $from)]')
    fi
    if [[ -n "$to_date" ]]; then
      local to_end="${to_date}T23:59:59"
      workouts=$(echo "$workouts" | jq --arg to "$to_end" '[.[] | select(.start_time <= $to)]')
    fi

    # Sort by date descending
    workouts=$(echo "$workouts" | jq 'sort_by(.start_time) | reverse')

    # Limit results
    if [[ -n "$limit" ]]; then
      workouts=$(echo "$workouts" | jq --argjson n "$limit" '.[:$n]')
    fi
  fi

  local count
  count=$(echo "$workouts" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    info "No workouts found"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$workouts" | jq .
  else
    echo -e "ID\tTITLE\tDATE\tDURATION\tEXERCISES"
    echo "$workouts" | jq -r '.[] | [
      .id,
      .title,
      (.start_time | split("T")[0]),
      (if .end_time and .start_time then
        # Handle timezone offset by replacing +00:00 with Z for fromdateiso8601
        ((((.end_time | sub("\\+00:00$"; "Z")) | sub("\\+00:00$"; "Z") | fromdateiso8601) - (((.start_time | sub("\\+00:00$"; "Z")) | sub("\\+00:00$"; "Z") | fromdateiso8601))) / 60 | floor | tostring) + "m"
      else "?" end),
      (.exercise_count // (.exercises | length))
    ] | @tsv' | table
  fi
}

# Get workout by ID
workouts_get() {
  local id="$1"

  if [[ -z "$id" ]]; then
    die "Usage: hevy workouts get <id>"
  fi

  local response
  response=$(api_get "/v1/workouts/$id") || exit 1

  # API returns {"workout": ...}
  local workout
  workout=$(echo "$response" | jq '.workout // .')

  # Cache the fetched workout (handles workouts added via app)
  cache_workouts_upsert "[$workout]"

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$workout" | jq .
  else
    # Display workout details
    echo "$workout" | jq -r '
      "Title: \(.title)",
      "ID: \(.id)",
      "Date: \(.start_time | split("T")[0])",
      "Start: \(.start_time)",
      "End: \(.end_time // "in progress")",
      "",
      "Exercises:"
    '

    # Format exercises with actual performance
    echo "$workout" | jq -r '.exercises[] |
      "  \(.index + 1). \(.title // .exercise_template_id)",
      "     Sets performed:",
      (.sets[] | "       - \(if .weight_kg then "\(.weight_kg)kg x " else "" end)\(.reps // .duration_seconds // "?") \(.type)")
    '
  fi
}

# Find workouts by routine
workouts_by_routine() {
  local routine_id="$1"
  shift 2>/dev/null || true
  local limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last|-l|-n)
        limit="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -z "$routine_id" ]]; then
    die "Usage: hevy workouts by-routine <routine-id> [--last N]"
  fi

  # Use cache for fast lookup (auto-refreshes if stale)
  local workouts
  workouts=$(cache_workouts_by_routine "$routine_id" "$limit")

  local count
  count=$(echo "$workouts" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    info "No workouts found for routine: $routine_id"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$workouts" | jq .
  else
    info "Found $count workout(s) using routine $routine_id"
    echo ""
    echo -e "ID\tTITLE\tDATE\tDURATION"
    echo "$workouts" | jq -r '.[] | [
      .id,
      .title,
      (.start_time | split("T")[0]),
      (if .end_time and .start_time then
        (((.end_time | sub("\\+00:00$"; "Z") | fromdateiso8601) - (.start_time | sub("\\+00:00$"; "Z") | fromdateiso8601)) / 60 | floor | tostring) + "m"
      else "?" end)
    ] | @tsv' | table
  fi
}

# Export workouts
workouts_export() {
  local format="json"
  local from_date=""
  local to_date=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format|-f)
        format="$2"
        shift 2
        ;;
      --from)
        from_date=$(parse_date "$2")
        shift 2
        ;;
      --to)
        to_date=$(parse_date "$2")
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local workouts
  workouts=$(paginate_all "/v1/workouts" "workouts") || exit 1

  # Filter by date range
  if [[ -n "$from_date" ]]; then
    workouts=$(echo "$workouts" | jq --arg from "$from_date" '[.[] | select(.start_time >= $from)]')
  fi
  if [[ -n "$to_date" ]]; then
    local to_end="${to_date}T23:59:59"
    workouts=$(echo "$workouts" | jq --arg to "$to_end" '[.[] | select(.start_time <= $to)]')
  fi

  # Sort by date
  workouts=$(echo "$workouts" | jq 'sort_by(.start_time)')

  case "$format" in
    json)
      echo "$workouts" | jq .
      ;;
    md|markdown)
      export_markdown "$workouts"
      ;;
    csv)
      export_csv "$workouts"
      ;;
    *)
      die "Unknown format: $format (use: json, md, csv)"
      ;;
  esac
}

# Export as markdown
export_markdown() {
  local workouts="$1"

  echo "# Workout History"
  echo ""

  echo "$workouts" | jq -r '.[] |
    "## \(.title) - \(.start_time | split("T")[0])",
    "",
    "**Duration:** \(if .end_time and .start_time then (((.end_time | sub("\\+00:00$"; "Z") | fromdateiso8601) - (.start_time | sub("\\+00:00$"; "Z") | fromdateiso8601)) / 60 | floor | tostring) + " minutes" else "Unknown" end)",
    "",
    "### Exercises",
    "",
    (.exercises[] |
      "#### \(.title // .exercise_template_id)",
      "",
      "| Set | Weight | Reps | Type |",
      "|-----|--------|------|------|",
      (.sets[] | "| \(.index + 1) | \(.weight_kg // "-")kg | \(.reps // .duration_seconds // "-") | \(.type) |"),
      ""
    ),
    "---",
    ""
  '
}

# Export as CSV
export_csv() {
  local workouts="$1"

  echo "date,workout_title,exercise,set_num,type,weight_kg,reps,duration_seconds,distance_meters"

  echo "$workouts" | jq -r '.[] |
    .start_time as $date |
    .title as $workout |
    .exercises[] |
    .title as $exercise |
    .sets[] |
    [
      ($date | split("T")[0]),
      $workout,
      $exercise,
      (.index + 1),
      .type,
      (.weight_kg // ""),
      (.reps // ""),
      (.duration_seconds // ""),
      (.distance_meters // "")
    ] | @csv
  '
}
