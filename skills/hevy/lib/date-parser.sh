#!/bin/bash
# Hevy CLI - Natural date parsing
# Requires: lib/common.sh sourced first

# ============================================================================
# Date parsing
# ============================================================================

# Detect if we're on macOS or Linux
_is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

# Parse natural language date to YYYY-MM-DD
# Usage: parse_date "yesterday" -> 2024-01-15
# Supports: today, yesterday, N days ago, last week, last month, ISO dates
parse_date() {
  local input="$1"

  # Already in YYYY-MM-DD format
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "$input"
    return 0
  fi

  # Handle common natural language inputs
  local result
  local input_lower
  input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  case "$input_lower" in
    today)
      if _is_macos; then
        result=$(date "+%Y-%m-%d")
      else
        result=$(date "+%Y-%m-%d")
      fi
      ;;

    yesterday)
      if _is_macos; then
        result=$(date -v-1d "+%Y-%m-%d")
      else
        result=$(date -d "yesterday" "+%Y-%m-%d")
      fi
      ;;

    "last week"|"1 week ago"|"a week ago")
      if _is_macos; then
        result=$(date -v-7d "+%Y-%m-%d")
      else
        result=$(date -d "7 days ago" "+%Y-%m-%d")
      fi
      ;;

    "last month"|"1 month ago"|"a month ago")
      if _is_macos; then
        result=$(date -v-1m "+%Y-%m-%d")
      else
        result=$(date -d "1 month ago" "+%Y-%m-%d")
      fi
      ;;

    *)
      # Try to parse "N days ago" pattern
      if [[ "$input" =~ ^([0-9]+)\ *days?\ *ago$ ]]; then
        local days="${BASH_REMATCH[1]}"
        if _is_macos; then
          result=$(date -v-${days}d "+%Y-%m-%d")
        else
          result=$(date -d "$days days ago" "+%Y-%m-%d")
        fi
      # Try to parse "N weeks ago" pattern
      elif [[ "$input" =~ ^([0-9]+)\ *weeks?\ *ago$ ]]; then
        local weeks="${BASH_REMATCH[1]}"
        local days=$((weeks * 7))
        if _is_macos; then
          result=$(date -v-${days}d "+%Y-%m-%d")
        else
          result=$(date -d "$days days ago" "+%Y-%m-%d")
        fi
      # Try to parse "N months ago" pattern
      elif [[ "$input" =~ ^([0-9]+)\ *months?\ *ago$ ]]; then
        local months="${BASH_REMATCH[1]}"
        if _is_macos; then
          result=$(date -v-${months}m "+%Y-%m-%d")
        else
          result=$(date -d "$months months ago" "+%Y-%m-%d")
        fi
      else
        # Last resort: try native date parsing
        if _is_macos; then
          # macOS date doesn't support -d, try to handle as-is
          die "Cannot parse date: $input (use YYYY-MM-DD, 'today', 'yesterday', 'N days ago')"
        else
          result=$(date -d "$input" "+%Y-%m-%d" 2>/dev/null) || \
            die "Cannot parse date: $input"
        fi
      fi
      ;;
  esac

  echo "$result"
}

# Get ISO 8601 timestamp for a date (start of day UTC)
# Usage: date_to_iso "2024-01-15" -> 2024-01-15T00:00:00Z
date_to_iso() {
  local date="$1"
  echo "${date}T00:00:00Z"
}

# Get end of day timestamp
# Usage: date_to_iso_end "2024-01-15" -> 2024-01-15T23:59:59Z
date_to_iso_end() {
  local date="$1"
  echo "${date}T23:59:59Z"
}

# Format ISO timestamp for display
# Usage: format_date "2024-01-15T10:30:00Z" -> "Jan 15, 2024"
format_date() {
  local iso="$1"
  local date_part="${iso%%T*}"

  if _is_macos; then
    date -j -f "%Y-%m-%d" "$date_part" "+%b %d, %Y" 2>/dev/null || echo "$date_part"
  else
    date -d "$date_part" "+%b %d, %Y" 2>/dev/null || echo "$date_part"
  fi
}

# Get relative date description
# Usage: relative_date "2024-01-15" -> "3 days ago"
relative_date() {
  local date="$1"
  local today
  local target

  if _is_macos; then
    today=$(date "+%s")
    target=$(date -j -f "%Y-%m-%d" "$date" "+%s" 2>/dev/null) || {
      echo "$date"
      return
    }
  else
    today=$(date "+%s")
    target=$(date -d "$date" "+%s" 2>/dev/null) || {
      echo "$date"
      return
    }
  fi

  local diff=$(( (today - target) / 86400 ))

  if [[ $diff -eq 0 ]]; then
    echo "today"
  elif [[ $diff -eq 1 ]]; then
    echo "yesterday"
  elif [[ $diff -lt 7 ]]; then
    echo "$diff days ago"
  elif [[ $diff -lt 30 ]]; then
    local weeks=$((diff / 7))
    if [[ $weeks -eq 1 ]]; then
      echo "1 week ago"
    else
      echo "$weeks weeks ago"
    fi
  else
    local months=$((diff / 30))
    if [[ $months -eq 1 ]]; then
      echo "1 month ago"
    else
      echo "$months months ago"
    fi
  fi
}
