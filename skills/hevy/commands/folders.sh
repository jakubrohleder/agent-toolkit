#!/bin/bash
# Hevy CLI - Folders command
# Usage: hevy folders <subcommand> [options]

show_folders_help() {
  cat <<'EOF'
hevy folders - Manage routine folders

Usage: hevy folders <command> [options]

Commands:
  list                 List all folders
  create <title>       Create a new folder
  delete <id>          Delete a folder (requires confirmation)

Options:
  --help, -h           Show this help
  --yes, -y            Skip confirmation for delete

Examples:
  hevy folders list
  hevy folders create "My Programs"
  hevy folders delete 12345
EOF
}

cmd_main() {
  local subcommand="${1:-list}"
  shift 2>/dev/null || true

  case "$subcommand" in
    --help|-h|help)
      show_folders_help
      ;;
    list|ls)
      folders_list "$@"
      ;;
    create|new|add)
      folders_create "$@"
      ;;
    delete|rm|remove)
      folders_delete "$@"
      ;;
    *)
      die "Unknown folders command: $subcommand. Run 'hevy folders --help'"
      ;;
  esac
}

# List all folders
folders_list() {
  local folders
  folders=$(paginate_all "/v1/routine_folders" "routine_folders") || exit 1

  local count
  count=$(echo "$folders" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    info "No folders found"
    return 0
  fi

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$folders" | jq .
  else
    echo -e "ID\tTITLE\tCREATED"
    echo "$folders" | jq -r '.[] | [.id, .title, (.created_at | split("T")[0])] | @tsv' | table
  fi
}

# Create a new folder
folders_create() {
  local title="$1"

  if [[ -z "$title" ]]; then
    die "Usage: hevy folders create <title>"
  fi

  local body
  body=$(jq -n --arg title "$title" '{routine_folder: {title: $title}}')

  debug "Creating folder: $title"
  local response
  response=$(api_post "/v1/routine_folders" "$body") || exit 1

  if [[ "$HEVY_JSON" == "true" ]]; then
    echo "$response" | jq .
  else
    local id name
    id=$(echo "$response" | jq -r '.routine_folder.id // .id // "unknown"')
    name=$(echo "$response" | jq -r '.routine_folder.title // .title // "unknown"')
    success "Created folder: $name (ID: $id)"
  fi
}

# Delete a folder
folders_delete() {
  local id="$1"

  if [[ -z "$id" ]]; then
    die "Usage: hevy folders delete <id>"
  fi

  # Confirm deletion
  if ! confirm "Delete folder $id?"; then
    info "Cancelled"
    return 0
  fi

  debug "Deleting folder: $id"
  api_delete "/v1/routine_folders/$id" || exit 1

  success "Deleted folder: $id"
}
