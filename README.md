# Ralph Standalone

Tiny shell tools for fast, repeatable agent workflows.

## Why people use Ralph

- Fast local execution
- Reusable prompt templates
- Minimal setup
- Works across projects

## Included scripts

- `afk.sh`
- `run-once.sh`

## Project layout

- `lib/ralph-common.sh`
- `prompts/base-build.md`
- `prompts/base-plan.md`

## Quick start

1. Add Ralph to your `PATH`:

```bash
export PATH="$HOME/Developer/ralph-standalone:$PATH"
```

2. Run from anywhere:

```bash
# With explicit spec
run-once.sh plan opencode tasks/spec.md

# Or rely on defaults when one exists:
# tasks/spec.md, spec.md, tasks/spec.json, spec.json
run-once.sh plan
```

## Contributing

Open a PR with focused improvements to scripts or prompts.
