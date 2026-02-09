#!/bin/bash
# Hevy CLI - Auto-pagination
# Requires: lib/common.sh and lib/api.sh sourced first

# ============================================================================
# Pagination
# ============================================================================

# Fetch all pages from a paginated endpoint
# Usage: paginate_all "/v1/routines" "routines" [page_size]
# Returns: Merged JSON array of all items
paginate_all() {
  local endpoint="$1"
  local array_key="$2"
  local page_size="${3:-100}"

  # Most Hevy endpoints have max pageSize of 10 (routine_folders, routines, workouts)
  # Only exercise_templates supports pageSize up to 100
  if [[ "$endpoint" != *"/exercise_templates"* ]]; then
    page_size=10
    debug "Using pageSize=10 for $endpoint"
  fi

  local page=1
  local all_items="[]"
  local page_count=1

  while [[ $page -le $page_count ]]; do
    debug "Fetching page $page of $page_count"

    # Build URL with pagination params
    local url
    if [[ "$endpoint" == *"?"* ]]; then
      url="${endpoint}&page=${page}&pageSize=${page_size}"
    else
      url="${endpoint}?page=${page}&pageSize=${page_size}"
    fi

    local response
    response=$(api_get "$url") || return 1

    # Get page count from first response
    if [[ $page -eq 1 ]]; then
      page_count=$(echo "$response" | jq -r '.page_count // 1')
      debug "Total pages: $page_count"
    fi

    # Extract items from this page
    local items
    items=$(echo "$response" | jq -r ".${array_key} // []")

    # Merge with accumulated items
    all_items=$(echo "$all_items" "$items" | jq -s 'add')

    ((page++))
  done

  # Return merged array
  echo "$all_items"
}

# Fetch all pages and return as object with metadata
# Usage: paginate_all_with_meta "/v1/routines" "routines"
# Returns: {"items": [...], "total_pages": N, "total_items": N}
paginate_all_with_meta() {
  local endpoint="$1"
  local array_key="$2"

  local items
  items=$(paginate_all "$endpoint" "$array_key") || return 1

  local count
  count=$(echo "$items" | jq 'length')

  jq -n \
    --argjson items "$items" \
    --argjson count "$count" \
    '{items: $items, total_items: $count}'
}

# Fetch a single page
# Usage: paginate_single "/v1/routines" "routines" [page] [page_size]
# Returns: JSON object with items and pagination info
paginate_single() {
  local endpoint="$1"
  local array_key="$2"
  local page="${3:-1}"
  local page_size="${4:-100}"

  # Most Hevy endpoints have max pageSize of 10 (routine_folders, routines, workouts)
  # Only exercise_templates supports pageSize up to 100
  if [[ "$endpoint" != *"/exercise_templates"* ]]; then
    page_size=10
  fi

  local url
  if [[ "$endpoint" == *"?"* ]]; then
    url="${endpoint}&page=${page}&pageSize=${page_size}"
  else
    url="${endpoint}?page=${page}&pageSize=${page_size}"
  fi

  local response
  response=$(api_get "$url") || return 1

  # Return response as-is (includes pagination metadata)
  echo "$response"
}
