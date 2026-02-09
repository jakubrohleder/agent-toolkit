---
name: hevy
description: |
  Create workout routines in Hevy fitness app. Converts training programs (text/PDF/image)
  to Hevy JSON format via CLI. Look up exercise IDs, build routine JSON, create via API.

  Use when: creating gym routines, importing workout plans, looking up exercise IDs,
  building workout JSON, converting programs (PPL, 5x5, 531, GZCLP, nSuns, Starting Strength,
  PHUL, PHAT, Upper/Lower, Full Body), syncing to Hevy, or any Hevy API task.

  Keywords: fitness app, workout tracker, routine builder, gym program, strength training,
  hypertrophy, exercise database, training log, weightlifting, bodybuilding

  User-invocable: /hevy
---

# Hevy Routine Creator

## Quick Start

```bash
<skill-dir>/bin/hevy auth <key>           # Authenticate (get key from hevy.com/settings)
<skill-dir>/bin/hevy exercises search "squat"
<skill-dir>/bin/hevy routines template > routine.json
# Edit routine.json
<skill-dir>/bin/hevy routines create routine.json
```

For all commands: `<skill-dir>/bin/hevy --help`

## Workflow

1. **Parse workout plan** - extract exercises, sets, reps, weights, rest times
2. **Look up exercise IDs** - `hevy exercises search <name>`
3. **Build routine JSON** - start with `hevy routines template`
4. **Create routine** - `hevy routines create file.json`

## Critical Rules

- **NEVER** use `@` in notes (causes silent 400 errors)
- **ALWAYS** wrap: `{"routine": {...}}` not bare object
- **ALWAYS** match set properties to exercise type:
  - `weight_reps` → weight_kg, reps
  - `reps_only` → reps only (NO weight!)
  - `duration` → duration_seconds
  - `distance_duration` → distance_meters, duration_seconds
- **NEVER** guess IDs - always `hevy exercises search`

## Exercise Type Decision

| User describes... | Exercise Type | Set Properties |
|-------------------|---------------|----------------|
| Weight + reps ("3x10 @ 135lb") | `weight_reps` | weight_kg, reps |
| Just reps ("3x12 pull-ups") | `reps_only` | reps only |
| Time hold ("60s plank") | `duration` | duration_seconds |
| Distance + time ("500m row") | `distance_duration` | distance_meters, duration_seconds |

**When unsure**: `hevy exercises get <id>` shows the exercise type.

## Interpreting Workout Plans

**Supersets:**
- "A1/A2", "superset", "paired" → same `superset_id` (integers: 0, 1, 2...)
- "Circuit" or "EMOM" → all exercises share one superset_id
- Separate exercises → `superset_id: null`

**Rest:** Goes on LAST exercise of superset only

**AMRAP/Max effort:** Use `"reps": null`

**Example superset structure:**
```json
{
  "exercise_template_id": "79D0BB3A",
  "superset_id": 0,
  "rest_seconds": null,
  "sets": [{"type": "normal", "weight_kg": 80, "reps": 10}]
},
{
  "exercise_template_id": "1B2B1E7C",
  "superset_id": 0,
  "rest_seconds": 90,
  "sets": [{"type": "normal", "reps": 8}]
}
```

## Common Exercise IDs

Use `hevy exercises search` for current IDs. These are reference examples:

| Exercise | ID | Type |
|----------|-----|------|
| Squat (Barbell) | `D04AC939` | weight_reps |
| Deadlift (Barbell) | `C6272009` | weight_reps |
| Bench Press (Barbell) | `79D0BB3A` | weight_reps |
| Overhead Press (Barbell) | `AE23FF09` | weight_reps |
| Pull Up | `1B2B1E7C` | reps_only |
| Push Up | `392887AA` | reps_only |
| Rowing Machine | `0222DB42` | distance_duration |
| Stretching | `527DA061` | duration |

## Before Creating Custom Exercises

1. Search partial names ("row" not "cable row")
2. Check equipment variants (Barbell, Dumbbell, Cable, Machine)
3. Try alternate names ("Skull Crushers" = "Lying Tricep Extension")

## Unit Conversion

User provides lbs → convert to kg: `weight_kg = lbs / 2.205`

Round to nearest 0.5 kg for practical loading.

## Handling Search Results

| Scenario | Action |
|----------|--------|
| Exact match | Use that ID |
| Multiple similar (e.g., "Squat" returns Barbell, Dumbbell, Smith) | Pick equipment variant matching user's context |
| No results | Try shorter term ("tricep" not "tricep pushdown cable") |
| Still nothing | Create custom exercise only as last resort |

## Bulk Import Strategy

For programs with 10+ routines:
1. Build all JSON files first
2. Create one routine, verify it appears correctly in app
3. Create remaining with 2-second delays between calls
4. If 429 error: wait 60s, resume from failed routine

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| HTML response | `@` in notes | Replace with "at" |
| Exercise not found | Typo | Search partial name |
| 401 Unauthorized | Bad API key | `hevy auth test` |
| 429 Rate limit | Too many requests | Wait 60s, then retry |
| 400 Bad Request | Wrong set properties for exercise type | Check exercise type with `hevy exercises get <id>` |
| Field not allowed | Read-only field in update | Remove `id`, `created_at`, `updated_at` fields |
| Sets rejected | `weight_kg` on reps_only exercise | Remove weight, use only `reps` |

## CLI vs This File

| Need | Use |
|------|-----|
| Exact command syntax, all flags | `hevy <command> --help` |
| Workflow, gotchas, interpretation rules | This file |
| Exploring all capabilities | `hevy --help` |
