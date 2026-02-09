#!/bin/bash
# Hevy CLI - API wrapper
# Requires: lib/common.sh sourced first

# ============================================================================
# Core API call function
# ============================================================================

# Make an API call to Hevy
# Usage: api_call METHOD ENDPOINT [BODY_OR_FILE]
# Returns: JSON response on stdout, exits on error
api_call() {
  local method="${1:-GET}"
  local endpoint="$2"
  local body="$3"

  if [[ -z "$endpoint" ]]; then
    die "api_call: endpoint is required"
  fi

  local api_key
  api_key=$(get_api_key) || exit 1

  local url="${HEVY_BASE_URL}${endpoint}"
  local curl_args=(
    -s
    -w "\n%{http_code}"
    -X "$method"
    -H "api-key: $api_key"
  )

  # Add body if provided
  if [[ -n "$body" ]]; then
    curl_args+=(-H "Content-Type: application/json")

    # Check if body is a file path or raw JSON
    if [[ -f "$body" ]]; then
      debug "Reading body from file: $body"
      curl_args+=(-d "@$body")
    else
      curl_args+=(-d "$body")
    fi
  fi

  debug "API call: $method $url"

  local response
  response=$(curl "${curl_args[@]}" "$url")

  # Split response body and status code
  local http_code
  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  debug "HTTP status: $http_code"

  # Handle HTTP errors
  if [[ "$http_code" -ge 400 ]]; then
    handle_api_error "$http_code" "$response_body"
    return 1
  fi

  # Return successful response
  echo "$response_body"
}

# ============================================================================
# Error handling
# ============================================================================

handle_api_error() {
  local http_code="$1"
  local body="$2"

  # Check for HTML response (@ symbol bug or other issues)
  if echo "$body" | grep -q "^<!DOCTYPE\|^<html"; then
    die "Bad Request - check for @ symbol in notes or invalid JSON"
  fi

  # Map HTTP codes to helpful messages
  case "$http_code" in
    400)
      local error_msg
      error_msg=$(echo "$body" | jq -r '.error // .message // "Bad Request"' 2>/dev/null || echo "Bad Request")
      die "Bad Request: $error_msg"
      ;;
    401)
      die "Unauthorized - check your API key with: hevy auth test"
      ;;
    403)
      die "Forbidden - you don't have access to this resource"
      ;;
    404)
      die "Not found - resource doesn't exist"
      ;;
    422)
      local error_msg
      error_msg=$(echo "$body" | jq -r '.error // .message // "Validation failed"' 2>/dev/null || echo "Validation failed")
      die "Validation error: $error_msg"
      ;;
    429)
      die "Rate limited - wait 60 seconds and try again"
      ;;
    500|502|503)
      die "Hevy API error ($http_code) - try again in a few seconds"
      ;;
    *)
      local error_msg
      error_msg=$(echo "$body" | jq -r '.error // .message // empty' 2>/dev/null || true)
      if [[ -n "$error_msg" ]]; then
        die "API error ($http_code): $error_msg"
      else
        die "API error ($http_code): $body"
      fi
      ;;
  esac
}

# ============================================================================
# Convenience methods
# ============================================================================

# GET request
# Usage: api_get "/v1/routines?page=1"
api_get() {
  api_call GET "$1"
}

# POST request
# Usage: api_post "/v1/routines" '{"routine": {...}}' OR api_post "/v1/routines" file.json
api_post() {
  api_call POST "$1" "$2"
}

# PUT request
# Usage: api_put "/v1/routines/abc123" '{"routine": {...}}'
api_put() {
  api_call PUT "$1" "$2"
}

# DELETE request
# Usage: api_delete "/v1/routines/abc123"
api_delete() {
  api_call DELETE "$1"
}

# ============================================================================
# Response helpers
# ============================================================================

# Extract array from paginated response
# Usage: response | extract_array "routines"
extract_array() {
  local key="$1"
  jq -r ".$key // []"
}

# Get page count from response
# Usage: response | get_page_count
get_page_count() {
  jq -r '.page_count // 1'
}

# Get current page from response
# Usage: response | get_current_page
get_current_page() {
  jq -r '.page // 1'
}
