#!/bin/bash
# Hevy CLI - SQLite exercise cache
# Requires: lib/common.sh, lib/api.sh, lib/pagination.sh sourced first

# ============================================================================
# Cache database management
# ============================================================================

# Ensure cache database exists with proper schema
ensure_cache_db() {
  mkdir -p "$HEVY_CONFIG_DIR"

  if [[ ! -f "$HEVY_CACHE_DB" ]]; then
    debug "Creating cache database: $HEVY_CACHE_DB"
    sqlite3 "$HEVY_CACHE_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS exercises (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT NOT NULL,
  primary_muscle_group TEXT,
  secondary_muscle_groups TEXT,
  equipment TEXT,
  is_custom INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS workouts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  routine_id TEXT,
  start_time TEXT NOT NULL,
  end_time TEXT,
  exercise_count INTEGER,
  cached_at INTEGER
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  folder_id INTEGER,
  exercise_count INTEGER,
  updated_at TEXT,
  cached_at INTEGER
);

CREATE TABLE IF NOT EXISTS cache_meta (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE INDEX IF NOT EXISTS idx_exercises_title ON exercises(title);
CREATE INDEX IF NOT EXISTS idx_exercises_muscle ON exercises(primary_muscle_group);
CREATE INDEX IF NOT EXISTS idx_exercises_type ON exercises(type);
CREATE INDEX IF NOT EXISTS idx_exercises_custom ON exercises(is_custom);
CREATE INDEX IF NOT EXISTS idx_workouts_routine ON workouts(routine_id);
CREATE INDEX IF NOT EXISTS idx_workouts_start ON workouts(start_time);
SQL
    debug "Cache database created"
  fi
}

# Ensure new tables exist (for existing databases)
ensure_cache_tables() {
  ensure_cache_db

  # Add workouts table if missing
  sqlite3 "$HEVY_CACHE_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS workouts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  routine_id TEXT,
  start_time TEXT NOT NULL,
  end_time TEXT,
  exercise_count INTEGER,
  cached_at INTEGER
);

CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  folder_id INTEGER,
  exercise_count INTEGER,
  updated_at TEXT,
  cached_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_workouts_routine ON workouts(routine_id);
CREATE INDEX IF NOT EXISTS idx_workouts_start ON workouts(start_time);
SQL
}

# Check if exercise cache needs refresh (older than 24 hours)
cache_needs_refresh() {
  ensure_cache_db

  local last_refresh
  last_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='exercises_last_refresh'" 2>/dev/null)
  # Fallback to old key for backwards compatibility
  [[ -z "$last_refresh" ]] && last_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='last_refresh'" 2>/dev/null)

  if [[ -z "$last_refresh" ]]; then
    return 0  # Never refreshed
  fi

  local now
  now=$(date +%s)
  local age=$((now - last_refresh))
  local max_age=$((24 * 60 * 60))  # 24 hours

  [[ $age -gt $max_age ]]
}

# Check if workout cache needs refresh (older than 1 hour)
cache_workouts_needs_refresh() {
  ensure_cache_tables

  local last_refresh
  last_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='workouts_last_refresh'" 2>/dev/null)

  if [[ -z "$last_refresh" ]]; then
    return 0  # Never refreshed
  fi

  local now
  now=$(date +%s)
  local age=$((now - last_refresh))
  local max_age=$((1 * 60 * 60))  # 1 hour

  [[ $age -gt $max_age ]]
}

# Check if routine cache needs refresh (older than 1 hour)
cache_routines_needs_refresh() {
  ensure_cache_tables

  local last_refresh
  last_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='routines_last_refresh'" 2>/dev/null)

  if [[ -z "$last_refresh" ]]; then
    return 0  # Never refreshed
  fi

  local now
  now=$(date +%s)
  local age=$((now - last_refresh))
  local max_age=$((1 * 60 * 60))  # 1 hour

  [[ $age -gt $max_age ]]
}

# Refresh cache from API
cache_refresh() {
  ensure_cache_db
  info "Refreshing exercise cache..."

  local exercises
  exercises=$(paginate_all "/v1/exercise_templates" "exercise_templates") || {
    warn "Failed to fetch exercises from API"
    return 1
  }

  local count
  count=$(echo "$exercises" | jq 'length')
  debug "Fetched $count exercises"

  # Clear existing exercises
  sqlite3 "$HEVY_CACHE_DB" "DELETE FROM exercises"

  # Insert all exercises
  echo "$exercises" | jq -c '.[]' | while read -r ex; do
    local id title type muscle equipment is_custom secondary_muscles
    id=$(echo "$ex" | jq -r '.id')
    title=$(echo "$ex" | jq -r '.title')
    type=$(echo "$ex" | jq -r '.type')
    muscle=$(echo "$ex" | jq -r '.primary_muscle_group // ""')
    secondary_muscles=$(echo "$ex" | jq -r '.secondary_muscle_groups // [] | join(",")')
    equipment=$(echo "$ex" | jq -r '.equipment // ""')
    is_custom=$(echo "$ex" | jq -r 'if .is_custom then 1 else 0 end')

    # Escape single quotes for SQL
    title="${title//\'/\'\'}"

    sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO exercises (id, title, type, primary_muscle_group, secondary_muscle_groups, equipment, is_custom) VALUES ('$id', '$title', '$type', '$muscle', '$secondary_muscles', '$equipment', $is_custom)"
  done

  # Update refresh timestamp
  local now
  now=$(date +%s)
  sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO cache_meta (key, value) VALUES ('exercises_last_refresh', '$now')"
  # Keep old key for backwards compatibility
  sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO cache_meta (key, value) VALUES ('last_refresh', '$now')"

  success "Cached $count exercises"
}

# ============================================================================
# Workout cache functions
# ============================================================================

# Refresh workout cache from API
cache_workouts_refresh() {
  ensure_cache_tables
  info "Refreshing workout cache..."

  local workouts
  workouts=$(paginate_all "/v1/workouts" "workouts") || {
    warn "Failed to fetch workouts from API"
    return 1
  }

  local count
  count=$(echo "$workouts" | jq 'length')
  debug "Fetched $count workouts"

  # Clear existing workouts
  sqlite3 "$HEVY_CACHE_DB" "DELETE FROM workouts"

  # Insert all workouts
  echo "$workouts" | jq -c '.[]' | while read -r w; do
    local id title routine_id start_time end_time exercise_count
    id=$(echo "$w" | jq -r '.id')
    title=$(echo "$w" | jq -r '.title')
    routine_id=$(echo "$w" | jq -r '.routine_id // ""')
    start_time=$(echo "$w" | jq -r '.start_time')
    end_time=$(echo "$w" | jq -r '.end_time // ""')
    exercise_count=$(echo "$w" | jq -r '.exercises | length')

    # Escape single quotes for SQL
    title="${title//\'/\'\'}"

    local now
    now=$(date +%s)
    sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO workouts (id, title, routine_id, start_time, end_time, exercise_count, cached_at) VALUES ('$id', '$title', '$routine_id', '$start_time', '$end_time', $exercise_count, $now)"
  done

  # Update refresh timestamp
  local now
  now=$(date +%s)
  sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO cache_meta (key, value) VALUES ('workouts_last_refresh', '$now')"

  success "Cached $count workouts"
}

# Auto-refresh workouts if needed
cache_workouts_auto_refresh() {
  if cache_workouts_needs_refresh; then
    cache_workouts_refresh
  fi
}

# Query workouts by routine ID from cache
# Usage: cache_workouts_by_routine "routine-id" [limit]
cache_workouts_by_routine() {
  local routine_id="$1"
  local limit="${2:-}"

  cache_workouts_auto_refresh

  local limit_clause=""
  [[ -n "$limit" ]] && limit_clause="LIMIT $limit"

  sqlite3 -json "$HEVY_CACHE_DB" "
    SELECT id, title, routine_id, start_time, end_time, exercise_count
    FROM workouts
    WHERE routine_id = '$routine_id'
    ORDER BY start_time DESC
    $limit_clause
  " 2>/dev/null || echo "[]"
}

# Query workouts with optional date filters
# Usage: cache_workouts_list [from_date] [to_date] [limit]
cache_workouts_list() {
  local from_date="${1:-}"
  local to_date="${2:-}"
  local limit="${3:-}"

  cache_workouts_auto_refresh

  local where_clauses=()
  [[ -n "$from_date" ]] && where_clauses+=("start_time >= '$from_date'")
  [[ -n "$to_date" ]] && where_clauses+=("start_time <= '${to_date}T23:59:59'")

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(IFS=" AND "; echo "${where_clauses[*]}")"
  fi

  local limit_clause=""
  [[ -n "$limit" ]] && limit_clause="LIMIT $limit"

  sqlite3 -json "$HEVY_CACHE_DB" "
    SELECT id, title, routine_id, start_time, end_time, exercise_count
    FROM workouts
    $where
    ORDER BY start_time DESC
    $limit_clause
  " 2>/dev/null || echo "[]"
}

# Upsert workout(s) into cache
# Usage: cache_workouts_upsert "$workouts_json"
cache_workouts_upsert() {
  local workouts_json="$1"
  ensure_cache_tables

  local now
  now=$(date +%s)

  echo "$workouts_json" | jq -c '.[]? // .' | while read -r w; do
    local id title routine_id start_time end_time exercise_count
    id=$(echo "$w" | jq -r '.id // empty')
    [[ -z "$id" ]] && continue

    title=$(echo "$w" | jq -r '.title')
    routine_id=$(echo "$w" | jq -r '.routine_id // ""')
    start_time=$(echo "$w" | jq -r '.start_time')
    end_time=$(echo "$w" | jq -r '.end_time // ""')
    exercise_count=$(echo "$w" | jq -r '.exercises | length')

    # Escape single quotes for SQL
    title="${title//\'/\'\'}"

    sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO workouts (id, title, routine_id, start_time, end_time, exercise_count, cached_at) VALUES ('$id', '$title', '$routine_id', '$start_time', '$end_time', $exercise_count, $now)"
  done
}

# ============================================================================
# Routine cache functions
# ============================================================================

# Refresh routine cache from API
cache_routines_refresh() {
  ensure_cache_tables
  info "Refreshing routine cache..."

  local routines
  routines=$(paginate_all "/v1/routines" "routines") || {
    warn "Failed to fetch routines from API"
    return 1
  }

  local count
  count=$(echo "$routines" | jq 'length')
  debug "Fetched $count routines"

  # Clear existing routines
  sqlite3 "$HEVY_CACHE_DB" "DELETE FROM routines"

  # Insert all routines
  echo "$routines" | jq -c '.[]' | while read -r r; do
    local id title folder_id exercise_count updated_at
    id=$(echo "$r" | jq -r '.id')
    title=$(echo "$r" | jq -r '.title')
    folder_id=$(echo "$r" | jq -r '.folder_id // "NULL"')
    exercise_count=$(echo "$r" | jq -r '.exercises | length')
    updated_at=$(echo "$r" | jq -r '.updated_at // ""')

    # Escape single quotes for SQL
    title="${title//\'/\'\'}"

    local now
    now=$(date +%s)

    # Handle NULL folder_id properly
    if [[ "$folder_id" == "NULL" || "$folder_id" == "null" ]]; then
      sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO routines (id, title, folder_id, exercise_count, updated_at, cached_at) VALUES ('$id', '$title', NULL, $exercise_count, '$updated_at', $now)"
    else
      sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO routines (id, title, folder_id, exercise_count, updated_at, cached_at) VALUES ('$id', '$title', $folder_id, $exercise_count, '$updated_at', $now)"
    fi
  done

  # Update refresh timestamp
  local now
  now=$(date +%s)
  sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO cache_meta (key, value) VALUES ('routines_last_refresh', '$now')"

  success "Cached $count routines"
}

# Auto-refresh routines if needed
cache_routines_auto_refresh() {
  if cache_routines_needs_refresh; then
    cache_routines_refresh
  fi
}

# Get routine from cache (fallback to API)
# Usage: cache_routine_get "routine-id"
cache_routine_get() {
  local id="$1"
  ensure_cache_tables

  local result
  result=$(sqlite3 -json "$HEVY_CACHE_DB" "
    SELECT id, title, folder_id, exercise_count, updated_at
    FROM routines
    WHERE id = '$id'
  " 2>/dev/null)

  if [[ -z "$result" || "$result" == "[]" ]]; then
    # Fallback to API
    debug "Routine $id not in cache, trying API..."
    local response
    response=$(api_get "/v1/routines/$id") || return 1
    echo "$response" | jq '.routine // .'
  else
    echo "$result" | jq '.[0]'
  fi
}

# Upsert single routine into cache
# Usage: cache_routine_upsert "$routine_json"
cache_routine_upsert() {
  local routine_json="$1"
  ensure_cache_tables

  local id title folder_id exercise_count updated_at
  id=$(echo "$routine_json" | jq -r '.id // empty')
  [[ -z "$id" ]] && return 1

  title=$(echo "$routine_json" | jq -r '.title')
  folder_id=$(echo "$routine_json" | jq -r '.folder_id // "NULL"')
  exercise_count=$(echo "$routine_json" | jq -r '.exercises | length')
  updated_at=$(echo "$routine_json" | jq -r '.updated_at // ""')

  # Escape single quotes for SQL
  title="${title//\'/\'\'}"

  local now
  now=$(date +%s)

  # Handle NULL folder_id properly
  if [[ "$folder_id" == "NULL" || "$folder_id" == "null" ]]; then
    sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO routines (id, title, folder_id, exercise_count, updated_at, cached_at) VALUES ('$id', '$title', NULL, $exercise_count, '$updated_at', $now)"
  else
    sqlite3 "$HEVY_CACHE_DB" "INSERT OR REPLACE INTO routines (id, title, folder_id, exercise_count, updated_at, cached_at) VALUES ('$id', '$title', $folder_id, $exercise_count, '$updated_at', $now)"
  fi
}

# Delete routine from cache
# Usage: cache_routine_delete "routine-id"
cache_routine_delete() {
  local id="$1"
  ensure_cache_tables
  sqlite3 "$HEVY_CACHE_DB" "DELETE FROM routines WHERE id='$id'"
}

# List all cached routines
# Usage: cache_routines_list [folder_id]
cache_routines_list() {
  local folder_id="${1:-}"

  cache_routines_auto_refresh

  local where=""
  if [[ -n "$folder_id" ]]; then
    where="WHERE folder_id = $folder_id"
  fi

  sqlite3 -json "$HEVY_CACHE_DB" "
    SELECT id, title, folder_id, exercise_count, updated_at
    FROM routines
    $where
    ORDER BY title
  " 2>/dev/null || echo "[]"
}

# Auto-refresh if needed
cache_auto_refresh() {
  if cache_needs_refresh; then
    cache_refresh
  fi
}

# ============================================================================
# Cache queries
# ============================================================================

# Search exercises by title (fuzzy match)
# Usage: cache_search "squat" -> matching exercises
cache_search() {
  local query="$1"
  cache_auto_refresh

  # SQL LIKE with wildcards for fuzzy match
  local pattern="%${query}%"

  # Query with equipment priority for sorting
  sqlite3 -separator $'\t' "$HEVY_CACHE_DB" "
    SELECT id, title, type, equipment, primary_muscle_group, is_custom
    FROM exercises
    WHERE title LIKE '$pattern' ESCAPE '\\'
    ORDER BY
      CASE equipment
        WHEN 'barbell' THEN 1
        WHEN 'dumbbell' THEN 2
        WHEN 'kettlebell' THEN 3
        WHEN 'machine' THEN 4
        WHEN 'cable' THEN 5
        WHEN 'band' THEN 6
        WHEN 'bodyweight' THEN 7
        ELSE 8
      END,
      title
    LIMIT 50
  "
}

# Get exercise by ID
# Usage: cache_get "D04AC939" -> exercise JSON
cache_get() {
  local id="$1"
  cache_auto_refresh

  local result
  result=$(sqlite3 -json "$HEVY_CACHE_DB" "
    SELECT id, title, type, equipment, primary_muscle_group, secondary_muscle_groups, is_custom
    FROM exercises
    WHERE id = '$id'
  " 2>/dev/null)

  if [[ -z "$result" || "$result" == "[]" ]]; then
    # Try fetching from API as fallback
    debug "Exercise $id not in cache, trying API..."
    local response
    response=$(api_get "/v1/exercise_templates?page=1&pageSize=100") || return 1
    local exercise
    exercise=$(echo "$response" | jq ".exercise_templates[] | select(.id == \"$id\")")

    if [[ -z "$exercise" ]]; then
      return 1
    fi
    echo "$exercise"
  else
    echo "$result" | jq '.[0]'
  fi
}

# Get exercise type by ID (for validation)
# Usage: cache_get_type "D04AC939" -> "weight_reps"
cache_get_type() {
  local id="$1"
  cache_auto_refresh

  sqlite3 "$HEVY_CACHE_DB" "SELECT type FROM exercises WHERE id = '$id'" 2>/dev/null
}

# List exercises with optional filters
# Usage: cache_list [--type TYPE] [--muscle MUSCLE] [--custom]
cache_list() {
  local type_filter=""
  local muscle_filter=""
  local custom_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)
        type_filter="$2"
        shift 2
        ;;
      --muscle)
        muscle_filter="$2"
        shift 2
        ;;
      --custom)
        custom_only=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  cache_auto_refresh

  local where_clauses=()
  [[ -n "$type_filter" ]] && where_clauses+=("type = '$type_filter'")
  [[ -n "$muscle_filter" ]] && where_clauses+=("primary_muscle_group = '$muscle_filter'")
  [[ "$custom_only" == "true" ]] && where_clauses+=("is_custom = 1")

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(IFS=" AND "; echo "${where_clauses[*]}")"
  fi

  sqlite3 -separator $'\t' "$HEVY_CACHE_DB" "
    SELECT id, title, type, equipment, primary_muscle_group
    FROM exercises
    $where
    ORDER BY primary_muscle_group, title
  "
}

# Get all unique muscle groups
cache_muscle_groups() {
  cache_auto_refresh
  sqlite3 "$HEVY_CACHE_DB" "SELECT DISTINCT primary_muscle_group FROM exercises WHERE primary_muscle_group != '' ORDER BY primary_muscle_group"
}

# Get all unique equipment types
cache_equipment_types() {
  cache_auto_refresh
  sqlite3 "$HEVY_CACHE_DB" "SELECT DISTINCT equipment FROM exercises WHERE equipment != '' ORDER BY equipment"
}

# Format timestamp for display
_format_timestamp() {
  local ts="$1"
  if [[ -z "$ts" || "$ts" == "never" ]]; then
    echo "never"
    return
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    date -r "$ts" "+%Y-%m-%d %H:%M:%S"
  else
    date -d "@$ts" "+%Y-%m-%d %H:%M:%S"
  fi
}

# Get cache statistics
cache_stats() {
  ensure_cache_db
  ensure_cache_tables

  # Exercise stats
  local ex_total ex_custom ex_refresh
  ex_total=$(sqlite3 "$HEVY_CACHE_DB" "SELECT COUNT(*) FROM exercises" 2>/dev/null || echo "0")
  ex_custom=$(sqlite3 "$HEVY_CACHE_DB" "SELECT COUNT(*) FROM exercises WHERE is_custom = 1" 2>/dev/null || echo "0")
  ex_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='exercises_last_refresh'" 2>/dev/null)
  [[ -z "$ex_refresh" ]] && ex_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='last_refresh'" 2>/dev/null)

  # Workout stats
  local wo_total wo_refresh
  wo_total=$(sqlite3 "$HEVY_CACHE_DB" "SELECT COUNT(*) FROM workouts" 2>/dev/null || echo "0")
  wo_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='workouts_last_refresh'" 2>/dev/null)

  # Routine stats
  local rt_total rt_refresh
  rt_total=$(sqlite3 "$HEVY_CACHE_DB" "SELECT COUNT(*) FROM routines" 2>/dev/null || echo "0")
  rt_refresh=$(sqlite3 "$HEVY_CACHE_DB" "SELECT value FROM cache_meta WHERE key='routines_last_refresh'" 2>/dev/null)

  echo "Exercises:"
  echo "  Total: $ex_total ($ex_custom custom)"
  echo "  Last refresh: $(_format_timestamp "$ex_refresh")"
  echo "  TTL: 24 hours"
  echo ""
  echo "Workouts:"
  echo "  Total: $wo_total"
  echo "  Last refresh: $(_format_timestamp "$wo_refresh")"
  echo "  TTL: 1 hour"
  echo ""
  echo "Routines:"
  echo "  Total: $rt_total"
  echo "  Last refresh: $(_format_timestamp "$rt_refresh")"
  echo "  TTL: 1 hour"
  echo ""
  echo "Cache location: $HEVY_CACHE_DB"
}

# Clear cache
cache_clear() {
  if [[ -f "$HEVY_CACHE_DB" ]]; then
    rm "$HEVY_CACHE_DB"
    success "Cache cleared"
  else
    info "No cache to clear"
  fi
}
