# Routine Structure Examples

**Note:** All examples show the inner structure. Wrap in `{"routine": ...}` when sending to API. Replace `folder_id` with actual ID from `scripts/hevy-api GET /v1/routine_folders`.

## Basic Strength Routine

```json
{
  "title": "Strength Day - Lower Body",
  "folder_id": 2203739,
  "exercises": [
    {
      "exercise_template_id": "0222DB42",
      "superset_id": null,
      "rest_seconds": 0,
      "notes": "5 min easy pace",
      "sets": [
        {
          "type": "normal",
          "distance_meters": null,
          "duration_seconds": 300
        }
      ]
    },
    {
      "exercise_template_id": "D04AC939",
      "superset_id": null,
      "rest_seconds": 150,
      "notes": "Back Squat - 2:30 rest between sets",
      "sets": [
        {"type": "warmup", "weight_kg": 60, "reps": 10},
        {"type": "warmup", "weight_kg": 80, "reps": 5},
        {"type": "warmup", "weight_kg": 90, "reps": 3},
        {"type": "normal", "weight_kg": 100, "reps": 5},
        {"type": "normal", "weight_kg": 100, "reps": 5},
        {"type": "normal", "weight_kg": 100, "reps": 5},
        {"type": "normal", "weight_kg": 100, "reps": 5}
      ]
    },
    {
      "exercise_template_id": "2B4B7310",
      "superset_id": null,
      "rest_seconds": 120,
      "notes": "Romanian Deadlift",
      "sets": [
        {"type": "normal", "weight_kg": 80, "reps": 8},
        {"type": "normal", "weight_kg": 80, "reps": 8},
        {"type": "normal", "weight_kg": 80, "reps": 8}
      ]
    }
  ]
}
```

## Superset Example

Exercises with the same `superset_id` are performed back-to-back:

```json
{
  "exercises": [
    {
      "exercise_template_id": "79D0BB3A",
      "superset_id": 0,
      "rest_seconds": 0,
      "notes": "Bench Press",
      "sets": [
        {"type": "normal", "weight_kg": 60, "reps": 10},
        {"type": "normal", "weight_kg": 60, "reps": 10},
        {"type": "normal", "weight_kg": 60, "reps": 10}
      ]
    },
    {
      "exercise_template_id": "55E6546F",
      "superset_id": 0,
      "rest_seconds": 90,
      "notes": "Bent Over Row - rest 90s after superset",
      "sets": [
        {"type": "normal", "weight_kg": 50, "reps": 10},
        {"type": "normal", "weight_kg": 50, "reps": 10},
        {"type": "normal", "weight_kg": 50, "reps": 10}
      ]
    }
  ]
}
```

## Cardio/Conditioning Example

```json
{
  "exercises": [
    {
      "exercise_template_id": "0222DB42",
      "superset_id": null,
      "rest_seconds": 90,
      "notes": "Row 500m intervals at 2:00/500m pace",
      "sets": [
        {"type": "normal", "distance_meters": 500, "duration_seconds": 120},
        {"type": "normal", "distance_meters": 500, "duration_seconds": 120},
        {"type": "normal", "distance_meters": 500, "duration_seconds": 120},
        {"type": "normal", "distance_meters": 500, "duration_seconds": 120}
      ]
    }
  ]
}
```

## Duration-based Exercise (Stretching/Mobility)

```json
{
  "exercises": [
    {
      "exercise_template_id": "527DA061",
      "superset_id": null,
      "rest_seconds": 0,
      "notes": "Full body stretching",
      "sets": [
        {"type": "normal", "duration_seconds": 600}
      ]
    }
  ]
}
```

## AMRAP/Test Style

For max reps tests, use a single set with target reps or leave open:

```json
{
  "exercise_template_id": "10313AFD",
  "superset_id": null,
  "rest_seconds": 300,
  "notes": "TEST: Max Thrusters bez przerwy (KB 24kg). Zapisz wynik!",
  "sets": [
    {"type": "warmup", "weight_kg": 16, "reps": 5},
    {"type": "warmup", "weight_kg": 16, "reps": 5},
    {"type": "normal", "weight_kg": 24, "reps": null}
  ]
}
```
