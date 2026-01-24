# Hevy API Reference

Base URL: `https://api.hevyapp.com`

## Authentication

All requests require the `api-key` header:
```
api-key: YOUR_API_KEY
```

**API key file:** `~/.hevy/.api_key` (plain text)

## Endpoints

### Exercise Templates

#### GET /v1/exercise_templates
List all available exercise templates (both built-in and custom).

**Query Parameters:**
- `page` (int): Page number, starting from 1
- `pageSize` (int): Items per page (max 100)

**Response:**
```json
{
  "page": 1,
  "page_count": 49,
  "exercise_templates": [
    {
      "id": "D04AC939",
      "title": "Squat (Barbell)",
      "type": "weight_reps",
      "primary_muscle_group": "quadriceps",
      "secondary_muscle_groups": ["glutes", "hamstrings"],
      "equipment": "barbell",
      "is_custom": false
    }
  ]
}
```

**Exercise Types:**
- `weight_reps` - weight and repetitions (e.g., squats, bench press)
- `reps_only` - only repetitions (e.g., pull-ups, push-ups)
- `duration` - time-based (e.g., planks, stretching)
- `distance_duration` - distance and time (e.g., rowing, running)

**Equipment values:**
- `barbell`, `dumbbell`, `kettlebell`, `machine`, `cable`, `band`, `bodyweight`, `other`, `none`

**Muscle groups:**
- `quadriceps`, `hamstrings`, `glutes`, `calves`, `chest`, `back`, `shoulders`, `biceps`, `triceps`, `forearms`, `abdominals`, `obliques`, `traps`, `lats`, `lower_back`, `upper_back`, `full_body`, `cardio`

#### POST /v1/exercise_templates
Create a custom exercise.

**Request Body:**
```json
{
  "exercise_template": {
    "title": "Sled Push",
    "type": "weight_reps",
    "primary_muscle_group": "quadriceps",
    "secondary_muscle_groups": ["glutes"],
    "equipment": "other"
  }
}
```

---

### Routine Folders

#### GET /v1/routine_folders
List all routine folders.

**Query Parameters:**
- `page` (int): Page number
- `pageSize` (int): Items per page

**Response:**
```json
{
  "page": 1,
  "page_count": 2,
  "routine_folders": [
    {
      "id": 2203739,
      "index": 0,
      "title": "Hyrox 2026",
      "updated_at": "2026-01-20T22:08:50.217Z",
      "created_at": "2026-01-20T22:05:42.062Z"
    }
  ]
}
```

#### POST /v1/routine_folders
Create a new routine folder.

**Request Body:**
```json
{
  "title": "My Folder Name"
}
```

---

### Routines

#### GET /v1/routines
List all routines.

**Query Parameters:**
- `page` (int): Page number
- `pageSize` (int): Items per page

**Response:**
```json
{
  "page": 1,
  "page_count": 20,
  "routines": [
    {
      "id": "uuid-string",
      "title": "Routine Name",
      "folder_id": 2203739,
      "updated_at": "2022-02-22T23:48:48.427Z",
      "created_at": "2022-02-04T09:46:30.162Z",
      "exercises": [...]
    }
  ]
}
```

#### POST /v1/routines
Create a new routine.

**Request Body:**
```json
{
  "routine": {
    "title": "Routine Name",
    "folder_id": 2203739,
    "exercises": [
    {
      "exercise_template_id": "D04AC939",
      "superset_id": null,
      "rest_seconds": 120,
      "notes": "Optional notes",
      "sets": [
        {
          "type": "warmup",
          "weight_kg": 60,
          "reps": 10
        },
        {
          "type": "normal",
          "weight_kg": 100,
          "reps": 5
        }
      ]
    }
  ]
  }
}
```

#### PUT /v1/routines/{routine_id}
Update an existing routine.

**CRITICAL: Read-only fields must be removed before sending!**

The API rejects these fields in PUT requests:
- `routine.id`
- `routine.folder_id`
- `routine.created_at`
- `routine.updated_at`
- `exercises[].index`
- `exercises[].title`
- `sets[].index`

**Request Body (after cleanup):**
```json
{
  "routine": {
    "title": "New Title",
    "exercises": [
      {
        "exercise_template_id": "D04AC939",
        "superset_id": null,
        "rest_seconds": 120,
        "notes": "Notes here",
        "sets": [
          {"type": "normal", "weight_kg": 100, "reps": 5}
        ]
      }
    ]
  }
}
```

Use `scripts/rename-routine.sh <id> "New Title"` for renaming.

---

### Workouts

#### GET /v1/workouts
List completed workouts.

#### POST /v1/workouts
Log a completed workout.

---

## Set Types

- `warmup` - Warm-up set (not counted in working sets)
- `normal` - Regular working set
- `failure` - Set to failure
- `dropset` - Drop set

## Set Properties

Properties depend on exercise type:

| Exercise Type | Set Properties |
|---------------|----------------|
| `weight_reps` | `weight_kg`, `reps` |
| `reps_only` | `reps` |
| `duration` | `duration_seconds` |
| `distance_duration` | `distance_meters`, `duration_seconds` |

All properties accept `number` or `null`.

## Supersets

Exercises with the same `superset_id` (integer) are grouped as a superset. Use `null` for non-superset exercises.

## Notes

- Exercise `index` in routines determines display order (0-based)
- `rest_seconds` defines rest time after the exercise (per exercise, not per set)
- Custom exercises have UUID-style IDs (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
- Built-in exercises have 8-character alphanumeric IDs (`D04AC939`)

## API Quirks

### CRITICAL: The `@` Symbol Bug
The `@` symbol in `notes` fields causes **silent Bad Request errors** (returns HTML instead of JSON).

- ❌ `@ 7:00/km` → Bad Request
- ✅ `at 7:00/km` or `7:00/km` → Works
- Other special chars (`:`, `/`, `-`, `!`) work fine

### Pagination Limits
- Most endpoints: `pageSize` max 100
- `routine_folders` endpoint: `pageSize` max **10** (not 100!)

### Response Format
- Routine responses return `{"routine": [...]}` (array, even for single item)
- Use `.routine[0].title` in jq, not `.routine.title`

### Naming Convention
Recommended format: `T{week} {day} - {description}`
- Example: `T1 Pon - Tempo Run`
- Example: `T2 Pt - Brick Hyrox Sim`

### Test/Max Effort Sets
For sets where reps are unknown (max effort tests), use `null`:
```json
{"type": "normal", "weight_kg": 24, "reps": null}
```

### Folder IDs
Query with `scripts/hevy-api GET /v1/routine_folders` to get current folder IDs.
