# Design: Replace IMPLEMENTATION_PLAN.md with prd.json

**Date:** 2026-04-07
**Status:** Approved

## Motivation

Anthropic's engineering article on effective harnesses for long-running agents explicitly recommends JSON over markdown for task tracking: "the model is less likely to inappropriately change or overwrite JSON files compared to Markdown files." The article also recommends external shell verification of task completion rather than relying on LLM self-assessment. The original snarktank/ralph reference implementation uses `prd.json` with `passes: true/false` per task. This change brings ralph-standalone into alignment with both.

## Section 1: Schema & File Roles

`prd.json` is an ordered JSON array. Array order = implicit priority. Plan mode AI creates it; build mode AI reads and updates it.

```json
[
  { "description": "Implement user authentication", "passes": false },
  { "description": "Add database schema migrations", "passes": false }
]
```

`prd.json` is initialized as `[]` by the shell. Plan mode overwrites it entirely on every run. Build mode flips individual entries from `passes: false` to `passes: true`.

**File roles:**
- `prd.json` — task list with pass/fail state. Replaces `IMPLEMENTATION_PLAN.md` entirely.
- `progress.txt` — unchanged. Append-only learnings/context log.
- `AGENTS.md` — unchanged. Validation commands and codebase patterns.
- `IMPLEMENTATION_PLAN.md` — removed. No backwards-compat shim.

## Section 2: Shell Changes

### `afk.sh`
- `plan_file="IMPLEMENTATION_PLAN.md"` → `prd_file="prd.json"`
- `jq` presence validated at startup via `ralph_validate_jq`; hard exit if missing
- After each **build** iteration, shell independently verifies completion:
  ```bash
  ralph_check_prd_complete "$prd_file"
  ```
  If all entries are `passes: true`, the loop exits as COMPLETE — regardless of whether the AI emitted the signal. This is additive to the signal check, not a replacement.
- Plan mode skips the shell verification check (plan mode writes prd.json, not consumes it; exits on COMPLETE signal only)

### `run-once.sh`
- Variable rename only: `plan_file` → `prd_file`
- No verification logic added (human-in-the-loop, human reads output)

## Section 3: Prompt Template Changes

### `base-plan.md`
- `{{PLAN_FILE}}` → `{{PRD_FILE}}`
- AI instructed to write `prd.json` as a strict JSON array, ordered by priority (high-risk architectural tasks first), all entries `passes: false`
- No freeform markdown — JSON only

### `base-build.md`
- `{{PLAN_FILE}}` → `{{PRD_FILE}}`
- AI instructed to:
  1. Read `prd.json`, find the first `passes: false` entry
  2. Implement that task
  3. Run feedback loops (typecheck, lint, tests)
  4. On success: set `passes: true` for that entry, commit, update `progress.txt`
- Added constraint: "Do not mark `passes: true` until tests pass. Do not mark multiple tasks complete in one iteration."

## Section 4: `ralph-common.sh` Changes

### Renamed/replaced functions
- `ralph_init_plan_file` removed entirely; replaced by `ralph_init_prd_file`:
  ```bash
  ralph_init_prd_file() {
    local prd_file="${1:-prd.json}"
    if [ ! -f "$prd_file" ]; then
      printf '[]\n' >"$prd_file"
      printf 'Initialized %s\n' "$prd_file"
    fi
  }
  ```

- New `ralph_validate_jq`:
  ```bash
  ralph_validate_jq() {
    if ! command -v jq &>/dev/null; then
      printf 'Error: jq is required but not installed.\n' >&2
      return 1
    fi
  }
  ```

- New `ralph_check_prd_complete`:
  ```bash
  ralph_check_prd_complete() {
    local prd_file="$1"
    local remaining
    remaining=$(jq '[.[] | select(.passes == false)] | length' "$prd_file")
    [ "$remaining" -eq 0 ]
  }
  ```

### Placeholder rename
- `{{PLAN_FILE}}` → `{{PRD_FILE}}` in `ralph_load_prompt_template` — sed substitution and supporting comments updated.

### Print functions
- `ralph_print_afk_header`, `ralph_print_afk_blocked`, `ralph_print_afk_max_iter` — parameter label `plan_file` → `prd_file`, no behavioral change.

## What Does Not Change

- Signal constants (`RALPH_SIGNAL_COMPLETE`, `RALPH_SIGNAL_BLOCKED`) — unchanged
- `progress.txt` role and initialization — unchanged
- `AGENTS.md` role and initialization — unchanged
- Loop structure, stuck detection, branch-per-run — unchanged
- Multi-CLI support — unchanged
- `run-once.sh` HITL behavior — unchanged
