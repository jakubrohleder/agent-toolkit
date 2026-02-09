# Hevy Skill

A Claude Code skill for creating workout routines in [Hevy](https://hevy.com), the workout tracking app.

## Install

```bash
npx skills add https://github.com/jakubrohleder/agent-toolkit --skill hevy
```

## What it does

Converts training plans into Hevy routines via their API. Give it a workout program (text, PDF, image, or description) and it creates the routine directly in your Hevy account.

Handles:
- Exercise mapping to Hevy's 400+ built-in exercises
- Sets, reps, weights, rest times
- Supersets and circuits
- Multi-week programs with folder organization

## Usage

```
/hevy
```

Then describe what you want: paste a training plan, share a PDF, or just describe the workout.

## Setup

1. Get your API key from [Hevy Developer Settings](https://hevy.com/settings?developer)
2. Run: `<skill-dir>/bin/hevy auth <your-api-key>`

Or manually:
```bash
mkdir -p ~/.hevy
echo "your-api-key-here" > ~/.hevy/.api_key
```

## CLI

The skill includes a full CLI for direct interaction:

```bash
<skill-dir>/bin/hevy --help              # Show all commands
<skill-dir>/bin/hevy exercises search squat
<skill-dir>/bin/hevy routines list
<skill-dir>/bin/hevy workouts list --from "last week"
```

## Files

- `SKILL.md` - Skill instructions and API quirks
- `bin/hevy` - CLI tool
- `lib/` - Shared bash libraries
- `commands/` - CLI subcommands
- `templates/` - JSON templates
- `tests/` - BATS test suite
