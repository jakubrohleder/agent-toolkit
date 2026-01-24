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
2. Save it to `~/.hevy/.api_key`

```bash
mkdir -p ~/.hevy
echo "your-api-key-here" > ~/.hevy/.api_key
```

## Files

- `SKILL.md` - Skill instructions and API quirks
- `references/` - Exercise IDs, JSON examples, API docs
- `scripts/` - API wrapper scripts
