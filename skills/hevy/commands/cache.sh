#!/bin/bash
# Hevy CLI - Cache command
# Usage: hevy cache <subcommand>

show_cache_help() {
  cat <<'EOF'
hevy cache - Manage local cache

Usage: hevy cache <command> [options]

Commands:
  refresh       Force refresh cache from API
  stats         Show cache statistics
  clear         Clear the cache

Options:
  --exercises   Refresh only exercises (24h TTL)
  --workouts    Refresh only workouts (1h TTL)
  --routines    Refresh only routines (1h TTL)
  --all         Refresh all caches (default)

The cache is stored in ~/.hevy/cache.db (SQLite) and automatically
refreshes based on TTL. Use 'hevy cache refresh' to force an update.

Examples:
  hevy cache refresh              # Refresh all caches
  hevy cache refresh --workouts   # Refresh only workouts
  hevy cache stats                # Show cache statistics
  hevy cache clear                # Clear all caches
EOF
}

cmd_main() {
  local subcommand="${1:-stats}"
  shift 2>/dev/null || true

  case "$subcommand" in
    --help|-h|help)
      show_cache_help
      ;;
    refresh|update)
      cache_refresh_cmd "$@"
      ;;
    stats|status|info)
      cache_stats
      ;;
    clear|clean|rm)
      cache_clear
      ;;
    *)
      die "Unknown cache command: $subcommand. Run 'hevy cache --help'"
      ;;
  esac
}

# Handle refresh command with optional flags
cache_refresh_cmd() {
  local do_exercises=false
  local do_workouts=false
  local do_routines=false
  local explicit=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --exercises|-e)
        do_exercises=true
        explicit=true
        shift
        ;;
      --workouts|-w)
        do_workouts=true
        explicit=true
        shift
        ;;
      --routines|-r)
        do_routines=true
        explicit=true
        shift
        ;;
      --all|-a)
        do_exercises=true
        do_workouts=true
        do_routines=true
        explicit=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  # Default: refresh all
  if [[ "$explicit" == "false" ]]; then
    do_exercises=true
    do_workouts=true
    do_routines=true
  fi

  local success_count=0
  local fail_count=0

  if [[ "$do_exercises" == "true" ]]; then
    if cache_refresh; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  fi

  if [[ "$do_workouts" == "true" ]]; then
    if cache_workouts_refresh; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  fi

  if [[ "$do_routines" == "true" ]]; then
    if cache_routines_refresh; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  fi

  if [[ "$fail_count" -gt 0 ]]; then
    warn "Some cache refreshes failed"
    return 1
  fi
}
