# Quick Reference

## Common Exercise IDs

| Exercise | ID | Type |
|----------|-----|------|
| Rowing Machine | `0222DB42` | distance_duration |
| Ski Machine | `42996e80-ce6f-4bf5-84e9-783c79e0316f` | distance_duration |
| Running | `AC1BB830` | distance_duration |
| Squat (Barbell) | `D04AC939` | weight_reps |
| Deadlift (Barbell) | `C6272009` | weight_reps |
| Bench Press (Barbell) | `79D0BB3A` | weight_reps |
| Overhead Press (Barbell) | `AE23FF09` | weight_reps |
| Thruster (KB) | `10313AFD` | weight_reps |
| Kettlebell Swing | `F8A0FCCA` | weight_reps |
| Wall Ball | `A1F47ACC` | weight_reps |
| Pull Up | `1B2B1E7C` | reps_only |
| Push Up | `392887AA` | reps_only |
| Burpee | `BB792A36` | reps_only |
| Stretching | `527DA061` | duration |

Full list: `references/exercises-by-category.md`

## Set Type Quick Reference

| Type | JSON | Use Case |
|------|------|----------|
| Warmup | `"type": "warmup"` | Light prep sets |
| Normal | `"type": "normal"` | Working sets |
| Failure | `"type": "failure"` | To failure |
| Drop | `"type": "dropset"` | Reduced weight |

## Exercise Type to Set Properties

| Exercise Type | Set Properties |
|---------------|----------------|
| `weight_reps` | `weight_kg`, `reps` |
| `reps_only` | `reps` |
| `duration` | `duration_seconds` |
| `distance_duration` | `distance_meters`, `duration_seconds` |

## Pre-Submit Checklist

Before POST/PUT, verify:

```
[ ] All exercise_template_ids exist in exercises-by-category.md or custom cache
[ ] Set properties match exercise type (weight_kg only for weight_reps, etc.)
[ ] No @ symbol anywhere in notes fields
[ ] JSON wrapped: {"routine": {...}}
[ ] For PUT: removed id, folder_id, created_at, updated_at, index, title
[ ] Superset exercises: only last one has rest_seconds > 0
[ ] folder_id is valid (fetched from /v1/routine_folders)
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `@` in notes | HTML response | Replace with "at" |
| Bare JSON object | 400 Bad Request | Wrap in `{"routine": ...}` |
| `reps` on duration exercise | 400 Bad Request | Use `duration_seconds` |
| `weight_kg` on reps_only | 400 Bad Request | Remove weight field |
| Read-only field in PUT | "field not allowed" | Remove per checklist |
