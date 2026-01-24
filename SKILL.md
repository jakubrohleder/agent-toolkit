---
name: hevy
description: |
  Create workout routines in the Hevy fitness app via API. User-invocable with /hevy.

  Use when: (1) User wants to create a Hevy routine from a training plan or description,
  (2) User asks to add exercises to Hevy, (3) User mentions "hevy routine" or similar.

  Triggers: "/hevy", "create hevy routine", "add to hevy", "hevy workout"
---

# Hevy Routine Creator

Create and manage workout routines in Hevy from training plans.

## Setup

API key: `~/.hevy/.api_key` (plain text, no quotes)

## Workflow

1. Parse workout plan - extract exercises, sets, reps, weights, rest times
2. **Read `references/api-reference.md`** - understand JSON structure and API quirks
3. Map exercises to IDs:
   - First: search `references/exercises-by-category.md` (standard Hevy exercises)
   - Then: check `~/.hevy/custom-exercises.md` for user's custom exercises (if exists)
   - If not found in either: fetch from API and cache (see Custom Exercises below)
   - If still no match: create custom exercise via API (see api-reference.md)
4. Build routine JSON - use `references/routine-examples.md` as template
5. Create/update via scripts

## Custom Exercises

User's custom exercises are cached locally at `~/.hevy/custom-exercises.md`.

**When to fetch/update the cache:**
- If `~/.hevy/custom-exercises.md` doesn't exist
- If user requests a refresh
- If an exercise isn't found in either file

**How to fetch and cache:**
```bash
mkdir -p ~/.hevy
scripts/hevy-api GET '/v1/exercise_templates?page=1&pageSize=100' | jq -r '
  .exercise_templates
  | group_by(.primary_muscle_group)
  | .[]
  | "## \(.[0].primary_muscle_group)\n" + (
      [.[] | "- `\(.id)` | \(.title) | \(.exercise_type) | \(.equipment)"] | join("\n")
    )
' > ~/.hevy/custom-exercises.md
```

**Always search both files** when matching exercises to find the best match.

## API Access

**IMPORTANT:** Read `references/api-reference.md` before making any API calls.

Use `scripts/hevy-api` for all API calls:
```bash
scripts/hevy-api GET /v1/routines                          # List routines
scripts/hevy-api GET /v1/routine_folders                   # List folders
scripts/hevy-api POST /v1/routines .tmp-hevy/routine.json  # Create routine
scripts/hevy-api PUT /v1/routines/<id> .tmp-hevy/routine.json
scripts/rename-routine.sh <id> "New Title"                 # Rename helper
```

**JSON files:** Write to `.tmp-hevy/`, clean up after:
```bash
mkdir -p .tmp-hevy
# write JSON to .tmp-hevy/routine.json
scripts/hevy-api POST /v1/routines .tmp-hevy/routine.json
rm -rf .tmp-hevy
```

## Quick Exercise IDs

| Exercise | ID | Type |
|----------|-----|------|
| Rowing Machine | `0222DB42` | distance_duration |
| Ski Machine | `42996e80-ce6f-4bf5-84e9-783c79e0316f` | distance_duration |
| Squat (Barbell) | `D04AC939` | weight_reps |
| Thruster (KB) | `10313AFD` | weight_reps |
| Stretching | `527DA061` | duration |

Full list: `references/exercises-by-category.md`

## Resources

- `references/api-reference.md` - **Read first!** JSON structure, set types, API quirks
- `references/exercises-by-category.md` - All exercises by muscle group
- `references/routine-examples.md` - JSON templates
