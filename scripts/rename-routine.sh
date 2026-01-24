#!/bin/bash
# Rename a Hevy routine
# Usage: ./rename-routine.sh <routine_id> <new_title>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <routine_id> <new_title>"
  exit 1
fi

ROUTINE_ID="$1"
NEW_TITLE="$2"
SCRIPT_DIR="$(dirname "$0")"

# Fetch routine
ROUTINE=$("$SCRIPT_DIR/hevy-api" GET "/v1/routines/$ROUTINE_ID")

if echo "$ROUTINE" | jq -e '.error' > /dev/null 2>&1; then
  echo "Error fetching routine: $(echo "$ROUTINE" | jq -r '.error')"
  exit 1
fi

# Create temp dir and write updated JSON
mkdir -p .tmp-hevy
echo "$ROUTINE" | jq "
  .routine.title = \"$NEW_TITLE\" |
  del(.routine.id, .routine.created_at, .routine.updated_at, .routine.folder_id) |
  .routine.exercises = [.routine.exercises[] | del(.index, .title) | .sets = [.sets[] | del(.index)]]
" > .tmp-hevy/rename.json

# Update routine
RESULT=$("$SCRIPT_DIR/hevy-api" PUT "/v1/routines/$ROUTINE_ID" .tmp-hevy/rename.json)

# Clean up
rm -rf .tmp-hevy

if echo "$RESULT" | jq -e '.error' > /dev/null 2>&1; then
  echo "Error updating routine: $(echo "$RESULT" | jq -r '.error')"
  exit 1
fi

NEW_NAME=$(echo "$RESULT" | jq -r '.routine[0].title')
echo "Renamed to: $NEW_NAME"
