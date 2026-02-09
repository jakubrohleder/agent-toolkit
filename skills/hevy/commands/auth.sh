#!/bin/bash
# Hevy CLI - Auth command
# Usage: hevy auth [api-key|test]

show_auth_help() {
  cat <<'EOF'
hevy auth - Manage API authentication

Usage: hevy auth [command] [options]

Commands:
  (no args)      Show authentication status
  <api-key>      Save API key to ~/.hevy/.api_key
  test           Test if current API key is valid

Options:
  --help, -h     Show this help

Examples:
  hevy auth                        Check if authenticated
  hevy auth abc123xyz              Save API key
  hevy auth test                   Verify API key works

Get your API key from: https://hevy.com/settings (API section)
EOF
}

cmd_main() {
  local subcommand="${1:-}"

  case "$subcommand" in
    --help|-h|help)
      show_auth_help
      ;;
    test)
      auth_test
      ;;
    "")
      auth_status
      ;;
    *)
      # Assume it's an API key
      auth_save "$subcommand"
      ;;
  esac
}

# Show current auth status
auth_status() {
  if is_authenticated; then
    local key
    key=$(cat "$HEVY_API_KEY_FILE" | tr -d '[:space:]')
    local masked="${key:0:4}...${key: -4}"
    success "Authenticated"
    echo "API key: $masked"
    echo "Config: $HEVY_API_KEY_FILE"
  else
    warn "Not authenticated"
    echo "Run: hevy auth <your-api-key>"
    echo "Get your key from: https://hevy.com/settings"
    return 1
  fi
}

# Save API key
auth_save() {
  local api_key="$1"

  # Basic validation
  if [[ ${#api_key} -lt 10 ]]; then
    die "API key seems too short. Check your key and try again."
  fi

  # Create config directory
  mkdir -p "$HEVY_CONFIG_DIR"

  # Save key with secure permissions
  echo -n "$api_key" > "$HEVY_API_KEY_FILE"
  chmod 600 "$HEVY_API_KEY_FILE"

  success "API key saved to $HEVY_API_KEY_FILE"

  # Test the key
  info "Testing API key..."
  if auth_test_quiet; then
    success "API key is valid"
  else
    warn "API key saved but test failed - verify your key"
    return 1
  fi
}

# Test API key (verbose)
auth_test() {
  if ! is_authenticated; then
    die "Not authenticated. Run: hevy auth <your-api-key>"
  fi

  info "Testing API key..."

  local response
  if response=$(api_get "/v1/exercise_templates?page=1&pageSize=1" 2>&1); then
    if echo "$response" | jq -e '.exercise_templates' >/dev/null 2>&1; then
      success "API key is valid"
      local count
      count=$(echo "$response" | jq -r '.page_count // 0')
      echo "Exercise pages available: $count"
      return 0
    fi
  fi

  die "API key test failed: $response"
}

# Test API key (quiet, for internal use)
auth_test_quiet() {
  local response
  response=$(api_get "/v1/exercise_templates?page=1&pageSize=1" 2>/dev/null) || return 1
  echo "$response" | jq -e '.exercise_templates' >/dev/null 2>&1
}
