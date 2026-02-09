---
name: hevy
description: |
  Create and edit workout routines in Hevy fitness app via API. User-invocable with /hevy.

  Use when: User wants to create/edit Hevy routines, convert training programs (text/PDF/image)
  to Hevy format, or work with the Hevy API.

  Triggers: "/hevy", "hevy routine", "add to hevy", "gym routine", "gym program",
  "lifting program", "training plan", "PPL", "push pull legs", "5x5", "531",
  "GZCLP", "nSuns", "import workout", "sync to hevy", "weightlifting"
---

# Hevy Routine Creator

## Quick Start

```bash
# Authenticate (get key from https://hevy.com/settings)
<skill-dir>/bin/hevy auth <your-api-key>

# Search for exercise IDs
<skill-dir>/bin/hevy exercises search "squat"
<skill-dir>/bin/hevy exercises search "pull up"

# Get routine template
<skill-dir>/bin/hevy routines template > routine.json

# Edit routine.json, then create
<skill-dir>/bin/hevy routines create routine.json

# List routines
<skill-dir>/bin/hevy routines list
```

## Workflow

1. **Parse workout plan** - extract exercises, sets, reps, weights, rest times
2. **Look up exercise IDs** using `<skill-dir>/bin/hevy exercises search <name>`
3. **Build routine JSON** (see `references/routine-examples.md` for structure)
4. **Create routine** with `<skill-dir>/bin/hevy routines create routine.json`

## CLI Reference

```bash
<skill-dir>/bin/hevy --help                    # Show all commands

# Authentication
<skill-dir>/bin/hevy auth                      # Check auth status
<skill-dir>/bin/hevy auth <key>                # Save API key
<skill-dir>/bin/hevy auth test                 # Verify key works

# Exercises (uses local SQLite cache, auto-refreshes every 24h)
<skill-dir>/bin/hevy exercises search <query>  # Fuzzy search by name
<skill-dir>/bin/hevy exercises list --muscle chest
<skill-dir>/bin/hevy exercises list --type weight_reps
<skill-dir>/bin/hevy exercises get <id>        # Get exercise details
<skill-dir>/bin/hevy exercises custom          # List custom exercises only
<skill-dir>/bin/hevy exercises types           # Show exercise type reference

# Folders
<skill-dir>/bin/hevy folders list
<skill-dir>/bin/hevy folders create "Folder Name"
<skill-dir>/bin/hevy folders delete <id>

# Routines
<skill-dir>/bin/hevy routines list
<skill-dir>/bin/hevy routines list --folder <id>
<skill-dir>/bin/hevy routines get <id>
<skill-dir>/bin/hevy routines template         # Output JSON skeleton
<skill-dir>/bin/hevy routines create file.json
<skill-dir>/bin/hevy routines create file.json --folder <id>
<skill-dir>/bin/hevy routines rename <id> "New Title"
<skill-dir>/bin/hevy routines duplicate <id> --title "Copy"
<skill-dir>/bin/hevy routines delete <id>

# Workouts (completed workout history)
<skill-dir>/bin/hevy workouts list
<skill-dir>/bin/hevy workouts list --from "last week"
<skill-dir>/bin/hevy workouts get <id>
<skill-dir>/bin/hevy workouts by-routine <routine-id>
<skill-dir>/bin/hevy workouts by-routine <routine-id> --last 5
<skill-dir>/bin/hevy workouts export --format md
<skill-dir>/bin/hevy workouts export --format csv --from "last month"

# Cache management
<skill-dir>/bin/hevy cache refresh             # Force refresh exercise cache
<skill-dir>/bin/hevy cache stats               # Show cache info
```

Global flags: `--json` (raw output), `--verbose` (debug info), `--quiet`, `--yes` (skip prompts)

## NEVER Do

- **NEVER** use `@` in notes fields - causes silent Bad Request
- **NEVER** forget wrapper: `{"routine": {...}}` not just `{...}`
- **NEVER** mismatch set properties and exercise type:
  - `weight_reps` → `weight_kg`, `reps`
  - `reps_only` → `reps` only (no weight!)
  - `duration` → `duration_seconds`
  - `distance_duration` → `distance_meters`, `duration_seconds`
- **NEVER** set `rest_seconds` on first exercise of superset (only last gets rest)
- **NEVER** guess exercise IDs - always verify with `hevy exercises search`

## Exercise Type Quick Reference

| Type | Set Properties | Examples |
|------|----------------|----------|
| `weight_reps` | `weight_kg`, `reps` | Squat, Bench Press, Deadlift |
| `reps_only` | `reps` | Pull-ups, Push-ups, Burpees |
| `duration` | `duration_seconds` | Plank, Stretching |
| `distance_duration` | `distance_meters`, `duration_seconds` | Rowing, Running |

## Set Types

| Type | JSON | Use Case |
|------|------|----------|
| Warmup | `"type": "warmup"` | Light prep sets |
| Normal | `"type": "normal"` | Working sets |
| Failure | `"type": "failure"` | To failure |
| Drop | `"type": "dropset"` | Reduced weight continuation |

Use `"reps": null` for AMRAP/max effort sets.

## Parsing Workout Plans

**Superset or sequential?**
- "A1/A2", "superset", "paired with" → same `superset_id` (use integers: 0, 1, 2...)
- "Circuit" or "EMOM" → all exercises share one `superset_id`
- Separate exercises with rest → `superset_id: null`

**Rest timing:**
- Hevy tracks rest per-exercise, not per-set
- For supersets: rest goes on LAST exercise only

**Before creating custom exercise, ask:**
- Did I search partial names? (e.g., "row" finds 15+ variations)
- Did I check equipment variants? (Barbell, Dumbbell, Cable, Machine)
- Could it exist under different name? ("Skull Crushers" = "Lying Tricep Extension")

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| HTML response / Bad Request | `@` in notes | Replace with "at" |
| Exercise not found | Typo or missing | Search partial name, check customs |
| 401 Unauthorized | Invalid API key | Run `hevy auth test` |
| 429 Rate limit | Too many requests | Wait 60s |

## References

- `references/routine-examples.md` - JSON structure examples
- `references/api-reference.md` - Full API documentation
- `references/quick-reference.md` - Common exercise IDs
- `references/exercises-by-category.md` - Complete exercise list (backup to CLI search)
